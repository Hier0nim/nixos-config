import { spawn } from 'node:child_process';
import { mkdtemp, readFile, realpath, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';
import { pathToFileURL } from 'node:url';

/** Send signal to the child's process group, if it still exists. */
function signalGroup(child, signal) {
  if (!child?.pid) return;
  try { process.kill(-child.pid, signal); }
  catch (error) { if (error.code !== 'ESRCH') throw error; }
}

/** Return the child's exit status, including a failed spawn. */
function completion(child) {
  return new Promise((resolve) => {
    child.once('error', () => resolve({ code: 1, signal: null }));
    child.once('exit', (code, signal) => resolve({ code, signal }));
  });
}

/** Terminate an owned group, including descendants after the direct child exits. */
async function stopGroup(child) {
  if (!child?.pid) return;
  signalGroup(child, 'SIGTERM');
  await sleep(400);
  signalGroup(child, 'SIGKILL');
  if (child.once && child.exitCode === null && child.signalCode === null) {
    await Promise.race([completion(child), sleep(200)]);
  } else {
    await sleep(50);
  }
}

/** Read Chromium's own port file within timeoutMs; reject exit or cancellation. */
async function endpoint(profile, child, isStopping, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (isStopping() || !child.pid || child.exitCode !== null || child.signalCode !== null) {
      throw new Error('Chromium stopped before readiness');
    }
    try {
      const [port, path] = (await readFile(join(profile, 'DevToolsActivePort'), 'utf8')).trim().split('\n');
      if (/^[0-9]+$/.test(port) && Number(port) > 0 && Number(port) < 65536
          && /^\/devtools\/browser\/[a-zA-Z0-9-]+$/.test(path)) {
        return `ws://127.0.0.1:${port}${path}`;
      }
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    await sleep(25);
  }
  throw new Error('Chromium readiness timed out');
}

/** Check the daemon's executable and session before using its PID. */
async function ownedDaemon(browser, session, directory, recordedPid) {
  try {
    const pid = recordedPid ?? Number((await readFile(join(directory, `${session}.pid`), 'utf8')).trim());
    if (!Number.isSafeInteger(pid) || pid <= 1) return null;
    const executable = await realpath(`/proc/${pid}/exe`);
    const env = (await readFile(`/proc/${pid}/environ`, 'utf8')).split('\0');
    if (executable === await realpath(browser)
        && env.includes(`AGENT_BROWSER_SOCKET_DIR=${directory}`)
        && env.includes(`AGENT_BROWSER_SESSION=${session}`)
        && env.includes('AGENT_BROWSER_DAEMON=1')) return { pid };
  } catch (error) {
    if (!['ENOENT', 'ESRCH'].includes(error.code)) throw error;
  }
  return null;
}

/** Close this session, then kill its daemon if it does not exit. */
async function closeSession(browser, session, env) {
  const directory = env.AGENT_BROWSER_SOCKET_DIR;
  // Do not start an agent-browser daemon just to close an unused session.
  const daemon = await ownedDaemon(browser, session, directory);
  if (!daemon) return;
  const child = spawn(browser, ['--session', session, 'close'], {
    env, detached: true, stdio: 'ignore',
  });
  const done = completion(child);
  await Promise.race([done, sleep(500)]);
  signalGroup(child, 'SIGKILL');
  await done;
  if (await ownedDaemon(browser, session, directory, daemon.pid)) await stopGroup(daemon);
  if (await ownedDaemon(browser, session, directory, daemon.pid)) {
    throw new Error('Owned browser daemon survived cleanup');
  }
}

/**
 * Forward args to Pi and give each RPC process its own browser.
 * pi, chromium and browser are executable paths. readyTimeoutMs limits startup.
 * tempRoot holds disposable profiles. Tests can override these defaults.
 */
export async function launch({
  args = process.argv.slice(2), pi = '/bin/pi-real',
  chromium = '/bin/chromium-headless', browser = '/bin/agent-browser',
  readyTimeoutMs = 15000, tempRoot = tmpdir(),
} = {}) {
  const rpc = args.some((arg, index) => arg === '--mode=rpc'
    || (arg === '--mode' && args[index + 1] === 'rpc'));
  if (!rpc) {
    // Preserve TTY behavior, signals, arguments and exit status without a proxy.
    process.execve(pi, [pi, ...args], process.env);
    throw new Error('execve unexpectedly returned');
  }

  process.umask(0o077);
  let directory;
  let chrome;
  let agent;
  let requestedSignal;
  let stopping = false;
  let failed = false;
  const onSignal = (signal) => {
    requestedSignal ??= signal;
    stopping = true;
    signalGroup(agent, signal);
    signalGroup(chrome, 'SIGTERM');
  };
  const handlers = new Map(['SIGTERM', 'SIGINT', 'SIGHUP'].map((signal) => {
    const handler = () => onSignal(signal);
    process.on(signal, handler);
    return [signal, handler];
  }));
  let result = { code: 1, signal: null };
  let session;
  let env;
  try {
    directory = await mkdtemp(join(tempRoot, 'open-design-run-'));
    session = directory.split('/').at(-1);
    chrome = spawn(chromium, [
      `--user-data-dir=${directory}`, '--remote-debugging-address=127.0.0.1',
      '--remote-debugging-port=0', '--no-first-run', '--no-default-browser-check',
      'about:blank',
    ], { detached: true, stdio: ['ignore', 'ignore', 'pipe'] });
    const chromeDone = completion(chrome);
    // Chromium diagnostics must not enter Pi's RPC output.
    chrome.stderr.resume();
    const cdp = await endpoint(directory, chrome, () => stopping, readyTimeoutMs);
    env = {
      ...process.env, OD_BROWSER_CDP_URL: cdp, AGENT_BROWSER_SESSION: session,
      AGENT_BROWSER_SOCKET_DIR: directory, AGENT_BROWSER_NAMESPACE: '',
    };
    if (stopping) throw new Error('Run canceled during browser startup');
    agent = spawn(pi, args, { env, detached: true, stdio: ['pipe', 'inherit', 'inherit'] });
    const agentDone = completion(agent);
    agent.stdin.on('error', (error) => {
      if (error.code !== 'EPIPE') {
        failed = true;
        onSignal('SIGTERM');
      }
    });
    process.stdin.pipe(agent.stdin);
    const first = await Promise.race([
      agentDone.then((status) => ({ agent: status })),
      chromeDone.then(() => ({ browserFailed: true })),
      // Continue cleanup even if Pi ignores the signal.
      (async () => { while (!stopping) await sleep(50); return { stopped: true }; })(),
    ]);
    if (first.browserFailed && !stopping) {
      failed = true;
      process.stderr.write('open-design: run browser exited unexpectedly\n');
    }
    result = first.agent ?? { code: 1, signal: requestedSignal ?? null };
    stopping = true;
    process.stdin.unpipe(agent.stdin);
    process.stdin.pause();
  } catch (error) {
    failed = true;
    process.stderr.write(`open-design: ${error.message}\n`);
  } finally {
    stopping = true;
    // Complete within upstream's 3-second signal grace period.
    const cleanup = await Promise.allSettled([
      stopGroup(agent),
      (async () => {
        try { if (session && env) await closeSession(browser, session, env); }
        finally { await stopGroup(chrome); }
      })(),
    ]);
    if (directory) {
      try { await rm(directory, { recursive: true, force: true }); }
      catch {
        failed = true;
        process.stderr.write('open-design: temporary profile removal failed\n');
      }
    }
    for (const [signal, handler] of handlers) process.off(signal, handler);
    if (cleanup.some((result) => result.status === 'rejected')) {
      failed = true;
      process.stderr.write('open-design: browser/process cleanup failed\n');
    }
  }
  const signal = requestedSignal ?? result.signal;
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }
  process.exitCode = failed ? 1 : (result.code ?? 1);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await launch();
}
