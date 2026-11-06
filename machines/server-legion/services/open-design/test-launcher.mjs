import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdir, mkdtemp, writeFile, readdir, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';

/** Create fake children in a private directory for test t. */
async function fixture(t) {
  const dir = await mkdtemp(join(tmpdir(), 'od-launcher-test-'));
  const runRoot = join(dir, 'runs');
  await mkdir(runRoot);
  const browser = join(dir, 'browser');
  const pi = join(dir, 'pi');
  const chromium = join(dir, 'chromium');
  const harness = join(dir, 'harness.mjs');
  await writeFile(browser, `#!${process.execPath}\nprocess.exit(0);\n`, { mode: 0o755 });
  await writeFile(pi, `#!${process.execPath}
const fs = require('node:fs');
if (!process.argv.includes('rpc') && !process.argv.includes('--mode=rpc')) {
  console.log(JSON.stringify(process.argv.slice(2))); process.exit(7);
}
fs.writeFileSync(process.env.PID_FILE, String(process.pid));
if (process.env.DESCENDANT) {
  const child = require('node:child_process').spawn(process.execPath, ['-e', "process.on('SIGTERM',()=>{});setInterval(()=>{},1000)"], {stdio:'ignore'});
  fs.writeFileSync(process.env.DESCENDANT_FILE, String(child.pid));
}
if (process.env.PI_STDERR) process.stderr.write('fake-pi-stderr\\n');
if (process.env.IGNORE_TERM) process.on('SIGTERM', () => {});
if (process.env.REPORT_ENV) console.log(JSON.stringify({cdp:process.env.OD_BROWSER_CDP_URL, session:process.env.AGENT_BROWSER_SESSION}));
process.stdin.on('data', (bytes) => { if (!process.stdout.write(bytes)) process.stdin.pause(); });
process.stdout.on('drain', () => process.stdin.resume());
process.stdin.on('end', () => process.exit(Number(process.env.PI_EXIT || 0)));
setInterval(() => {}, 1000);
`, { mode: 0o755 });
  await writeFile(chromium, `#!${process.execPath}
const fs = require('node:fs');
fs.writeFileSync(process.env.CHROME_PID_FILE, String(process.pid));
const profile = process.argv.find(a => a.startsWith('--user-data-dir=')).split('=').slice(1).join('=');
if (process.env.CHROME_FAIL) process.exit(2);
if (process.env.IGNORE_TERM) process.on('SIGTERM', () => {});
if (!process.env.CHROME_TIMEOUT) fs.writeFileSync(profile + '/DevToolsActivePort', '45678\\n/devtools/browser/abc-123\\n');
if (process.env.CHROME_LATE_FAIL) setTimeout(() => process.exit(3), 300);
setInterval(() => {}, 1000);
`, { mode: 0o755 });
  await writeFile(harness, `import {launch} from ${JSON.stringify(new URL('./pi-launcher.mjs', import.meta.url).href)};
await launch(${JSON.stringify({ pi, chromium, browser, tempRoot: runRoot, readyTimeoutMs: 2000 })});\n`);
  t.after(async () => { await rm(dir, { recursive: true, force: true }); });
  return { dir, runRoot, harness };
}

/** Start fixture f with args and env, then collect output and exit status. */
function start(f, args, env = {}) {
  const child = spawn(process.execPath, [f.harness, ...args], {
    env: { ...process.env, PID_FILE: join(f.dir, 'pi.pid'), CHROME_PID_FILE: join(f.dir, 'chrome.pid'), DESCENDANT_FILE: join(f.dir, 'descendant.pid'), ...env },
    stdio: ['pipe', 'pipe', 'pipe'],
  });
  let stdout = '';
  let stderr = '';
  child.stdout.on('data', (bytes) => { stdout += bytes; });
  child.stderr.on('data', (bytes) => { stderr += bytes; });
  const done = new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('exit', (code, signal) => resolve({ code, signal, stdout, stderr }));
  });
  return { child, done };
}

/** Wait for the child PID file, but fail if it does not appear. */
async function ready(f, filename = 'pi.pid') {
  for (let n = 0; n < 150; n++) {
    try { return Number(await readFile(join(f.dir, filename), 'utf8')); }
    catch (error) { if (error.code !== 'ENOENT') throw error; }
    await sleep(20);
  }
  throw new Error('Fake Pi did not start');
}

/** Check that fixture f has no profiles or live child pid. */
async function clean(f, pid) {
  assert.deepEqual(await readdir(f.runRoot), []);
  if (pid) assert.throws(() => process.kill(pid, 0), { code: 'ESRCH' });
}

test('CLI probes preserve arguments and status and start no browser', { timeout: 5000 }, async (t) => {
  const f = await fixture(t);
  const p = start(f, ['--version', 'a b', '--model=literal']);
  p.child.stdin.end();
  const result = await p.done;
  assert.equal(result.code, 7);
  assert.deepEqual(JSON.parse(result.stdout), ['--version', 'a b', '--model=literal']);
  await assert.rejects(readFile(join(f.dir, 'chrome.pid')), { code: 'ENOENT' });
  await clean(f);
});

test('RPC forwards bytes, EOF and nonzero exit without diagnostic stdout', { timeout: 5000 }, async (t) => {
  const f = await fixture(t);
  const p = start(f, ['--mode', 'rpc'], { PI_EXIT: '9', PI_STDERR: '1' });
  const pid = await ready(f);
  const bytes = `${JSON.stringify({ type: 'prompt', message: 'x'.repeat(250000) + '\u2028' })}\n`;
  p.child.stdin.end(bytes);
  const result = await p.done;
  assert.equal(result.stdout, bytes);
  assert.equal(result.code, 9);
  assert.equal(result.stderr, 'fake-pi-stderr\n');
  await clean(f, pid);
});

for (const signal of ['SIGTERM', 'SIGINT', 'SIGHUP']) {
  test(`${signal} is forwarded and cleanup escalates for stubborn children`, { timeout: 5000 }, async (t) => {
    const f = await fixture(t);
    const p = start(f, ['--mode=rpc'], { IGNORE_TERM: '1', DESCENDANT: '1' });
    const pid = await ready(f);
    const descendant = await ready(f, 'descendant.pid');
    p.child.kill(signal);
    const result = await p.done;
    assert.equal(result.signal, signal);
    await clean(f, pid);
    try {
      const status = await readFile(`/proc/${descendant}/stat`, 'utf8');
      assert.equal(status.split(') ')[1][0], 'Z', 'Descendant is still running');
    } catch (error) { if (error.code !== 'ENOENT') throw error; }
  });
}

test('cancellation during browser startup cleans up without starting Pi', { timeout: 5000 }, async (t) => {
  const f = await fixture(t);
  const p = start(f, ['--mode', 'rpc'], { CHROME_TIMEOUT: '1', IGNORE_TERM: '1' });
  const chrome = await ready(f, 'chrome.pid');
  p.child.kill('SIGTERM');
  const result = await p.done;
  assert.equal(result.signal, 'SIGTERM');
  assert.equal(result.stdout, '');
  await clean(f, chrome);
});

for (const mode of ['CHROME_FAIL', 'CHROME_TIMEOUT']) {
  test(`${mode} fails without launching Pi and cleans its profile`, { timeout: 5000 }, async (t) => {
    const f = await fixture(t);
    const p = start(f, ['--mode', 'rpc'], { [mode]: '1' });
    p.child.stdin.end();
    const result = await p.done;
    assert.equal(result.code, 1);
    assert.equal(result.stdout, '');
    assert.match(result.stderr, /Chromium/);
    await clean(f);
  });
}

test('browser failure terminates Pi and reports failure', { timeout: 5000 }, async (t) => {
  const f = await fixture(t);
  const p = start(f, ['--mode', 'rpc'], { CHROME_LATE_FAIL: '1' });
  const pid = await ready(f);
  const result = await p.done;
  assert.equal(result.code, 1);
  assert.match(result.stderr, /browser exited/);
  await clean(f, pid);
});

test('concurrent RPC processes have distinct profiles and session ownership', { timeout: 5000 }, async (t) => {
  const a = await fixture(t);
  const b = await fixture(t);
  const pa = start(a, ['--mode', 'rpc'], { REPORT_ENV: '1' });
  const pb = start(b, ['--mode', 'rpc'], { REPORT_ENV: '1' });
  const [pida, pidb] = await Promise.all([ready(a), ready(b)]);
  pa.child.stdin.end();
  const ra = await pa.done;
  assert.doesNotThrow(() => process.kill(pidb, 0));
  pb.child.stdin.end();
  const rb = await pb.done;
  const ea = JSON.parse(ra.stdout);
  const eb = JSON.parse(rb.stdout);
  assert.notEqual(ea.session, eb.session);
  assert.match(ea.cdp, /^ws:\/\/127\.0\.0\.1:45678\/devtools\/browser\//);
  await clean(a, pida);
  await clean(b, pidb);
});
