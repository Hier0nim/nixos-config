import assert from 'node:assert/strict';
import { spawn, execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { createServer } from 'node:http';
import { mkdtemp, readFile, readdir, rm, stat, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { launch } from './pi-launcher.mjs';

let phase = 'versions';

/** Run bin with args, limiting time and captured output. */
async function command(bin, args) {
  const { stdout } = await promisify(execFile)(bin, args, {
    encoding: 'utf8', timeout: 30000, maxBuffer: 1024 * 1024,
  });
  return stdout;
}

/** Send args to this run's browser session. */
async function browser(args) {
  const output = await command('/bin/agent-browser', ['--cdp', process.env.OD_BROWSER_CDP_URL, '--json', ...args]);
  const result = JSON.parse(output);
  assert.equal(result.success, true, 'Browser command failed');
  return result.data;
}

/** Check a real browser without a model or external website. */
async function browserChild() {
  const session = process.env.AGENT_BROWSER_SESSION;
  const server = createServer((_req, res) => {
    res.setHeader('Content-Type', 'text/html');
    res.end(`<!doctype html><title>${session}</title><p>Browser check</p>`);
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    await browser(['open', `http://127.0.0.1:${server.address().port}`]);
    const screenshot = join(process.env.OD_DOCTOR_DIR, `${session}.png`);
    await browser(['screenshot', screenshot]);
    assert.deepEqual([...(await readFile(screenshot)).subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
    assert.equal((await browser(['eval', 'document.title'])).result, session);
  } finally {
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
  }
}

/** Run a browser probe in a separate launcher process. */
async function browserRun(directory) {
  const child = spawn('/bin/node', ['/etc/open-design/doctor.mjs', '--launch'], {
    env: { ...process.env, OD_DOCTOR_DIR: directory }, stdio: ['ignore', 'ignore', 'inherit'],
  });
  const timer = setTimeout(() => child.kill('SIGTERM'), 60000);
  try {
    const status = await new Promise((resolve, reject) => {
      child.once('error', reject);
      child.once('exit', (code, signal) => resolve({ code, signal }));
    });
    assert.equal(status.code, 0, 'Browser probe failed');
    assert.equal(status.signal, null);
  } finally { clearTimeout(timer); }
}

/** Check concurrent sessions and cleanup using the installed browser binaries. */
async function browsers() {
  const directory = await mkdtemp(join(tmpdir(), 'open-design-doctor-'));
  try {
    const runs = await Promise.allSettled([browserRun(directory), browserRun(directory)]);
    for (const run of runs) if (run.status === 'rejected') throw run.reason;
    const files = await readdir(directory);
    assert.equal(files.filter((file) => file.endsWith('.png')).length, 2);
    assert.equal(files.filter((file) => file.startsWith('open-design-run-') && !file.endsWith('.png')).length, 0);
    for (const pid of (await readdir('/proc')).filter((entry) => /^[0-9]+$/.test(entry))) {
      let environment;
      try { environment = await readFile(`/proc/${pid}/environ`, 'utf8'); }
      catch (error) {
        if (['ENOENT', 'ESRCH', 'EACCES'].includes(error.code)) continue;
        throw error;
      }
      assert.ok(!environment.split('\0').includes(`OD_DOCTOR_DIR=${directory}`), 'Browser process survived cleanup');
    }
  } finally { await rm(directory, { recursive: true, force: true }); }
}

/** Check the running service. includeBrowser adds a real browser probe. */
async function doctor(includeBrowser) {
  const versions = JSON.parse(await readFile('/etc/open-design/versions.json', 'utf8'));
  console.log(JSON.stringify(versions));
  assert.equal((await command('/bin/pi', ['--version'])).trim(), versions.pi);
  assert.match(await command('/bin/agent-browser', ['--version']), new RegExp(versions.agentBrowser.replaceAll('.', '\\.')));
  assert.match(await command('/bin/chromium', ['--version']), new RegExp(versions.chromium.replaceAll('.', '\\.')));
  phase = 'state';
  assert.notEqual(process.getuid(), 0);
  for (const path of [process.env.OD_DATA_DIR, process.env.HOME, process.env.PI_CODING_AGENT_DIR]) {
    const metadata = await stat(path);
    assert.equal(metadata.mode & 0o777, 0o700);
    assert.equal(metadata.uid, process.getuid());
  }
  await assert.rejects(stat(join(process.env.PI_CODING_AGENT_DIR, 'SYSTEM.md')), { code: 'ENOENT' });
  const probe = await mkdtemp(join(process.env.OD_DATA_DIR, '.doctor-'));
  try { await writeFile(join(probe, 'write-test'), 'private'); }
  finally { await rm(probe, { recursive: true, force: true }); }
  phase = 'web UI';
  const health = await fetch('http://127.0.0.1:7456/api/health', { signal: AbortSignal.timeout(5000) });
  assert.equal(health.ok, true);
  assert.equal((await health.json()).version, versions.openDesignPackageVersion);
  const web = await fetch('http://127.0.0.1:7456/', { signal: AbortSignal.timeout(15000) });
  assert.equal(web.ok, true);
  const asset = (await web.text()).match(/<script[^>]+src="([^"]*\/_next\/static\/[^"]+)"/)?.[1];
  assert.ok(asset?.startsWith('/'), 'Compiled web UI script missing');
  const script = await fetch(new URL(asset, 'http://127.0.0.1:7456'), { signal: AbortSignal.timeout(5000) });
  assert.equal(script.ok, true);
  assert.match(script.headers.get('content-type') ?? '', /javascript/);
  const policy = await readFile('/etc/open-design/pi-policy.md', 'utf8');
  const response = await fetch('http://127.0.0.1:7456/api/app-config', { signal: AbortSignal.timeout(5000) });
  assert.equal(response.ok, true);
  assert.equal((await response.json()).config.customInstructions, policy);
  phase = 'Pi models';
  const listing = await command('/bin/pi', ['--list-models']);
  const { parsePiModels } = await import('/app/apps/daemon/dist/agent-protocol/pi-rpc/models.js');
  if (/^No models available\./.test(listing.trim())) {
    console.log('No Pi models configured. Log in with open-design-pi.');
  } else {
    const models = parsePiModels(listing);
    assert.ok(models?.length > 1, 'OpenDesign cannot parse the Pi model listing');
    console.log(`Pi models: ${models.length - 1}`);
  }
  if (includeBrowser) { phase = 'browser'; await browsers(); }
  console.log('Service checks passed. No model request was made.');
}

try {
  if (process.argv[2] === '--browser-child') await browserChild();
  else if (process.argv[2] === '--launch') await launch({
    args: ['/etc/open-design/doctor.mjs', '--browser-child', '--mode', 'rpc'],
    pi: '/bin/node', tempRoot: process.env.OD_DOCTOR_DIR,
  });
  else {
    assert.ok(process.argv.length === 2 || (process.argv.length === 3 && process.argv[2] === '--browser'));
    await doctor(process.argv[2] === '--browser');
  }
} catch (error) {
  // Child output and HTTP bodies may contain credentials.
  console.error(`open-design-doctor: ${phase}; ${error.code ?? 'check failed'}`);
  process.exitCode = 1;
}
