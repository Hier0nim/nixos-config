import assert from 'node:assert/strict';
import { spawn, execFileSync } from 'node:child_process';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

const [app, runtime, policyPath] = process.argv.slice(2);
/** Import a module from the completed, self-contained daemon deployment. */
const load = (module) => import(pathToFileURL(join(app, 'apps/daemon/dist', module)).href);
const policy = await readFile(policyPath, 'utf8');
const { composeSystemPrompt } = await load('prompts/system.js');
const prompt = composeSystemPrompt({ agentId: 'pi', userInstructions: policy, promptCoreVariant: 'slim' });
assert.ok(prompt.includes(policy.trim()), 'Operational policy missing from prompt');

const { mapPiRpcEvent } = await load('agent-protocol/pi-rpc/events.js');
assert.equal(mapPiRpcEvent({ type: 'agent_end' }, () => {}, { runStartedAt: 0, sentFirstToken: { value: false } }), null);
assert.equal(mapPiRpcEvent({ type: 'agent_settled' }, () => {}, { runStartedAt: 0, sentFirstToken: { value: false } }), 'agent_end');

// A fake key exposes the model catalogue without making a provider request.
const home = await mkdtemp(join(tmpdir(), 'od-preflight-'));
try {
  const env = { PATH: process.env.PATH, HOME: home, PI_CODING_AGENT_DIR: join(home, '.pi/agent'), OPENAI_API_KEY: 'not-a-real-key' };
  const cli = join(runtime, 'lib/node_modules/@earendil-works/pi-coding-agent/dist/cli.js');
  const listing = execFileSync(process.execPath, [cli, '--list-models'], { env, encoding: 'utf8', timeout: 15000 });
  const { parsePiModels } = await load('agent-protocol/pi-rpc/models.js');
  const parsed = parsePiModels(listing);
  assert.ok(parsed?.length > 1);
  const expected = listing.trim().split('\n').slice(1).map((line) => line.trim().split(/\s+/).slice(0, 2).join('/'));
  assert.deepEqual(parsed.slice(1).map((model) => model.id), [...new Set(expected)]);
  const child = spawn(process.execPath, [cli, '--mode', 'rpc', '--no-session'], { env, stdio: ['pipe', 'pipe', 'inherit'] });
  const timer = setTimeout(() => child.kill('SIGKILL'), 15000);
  let output = '';
  child.stdout.on('data', (bytes) => { output += bytes; });
  child.stdin.end('{"id":"state","type":"get_state"}\n');
  try {
    const code = await new Promise((resolve, reject) => {
      child.once('error', reject);
      child.once('exit', (status) => resolve(status));
    });
    assert.equal(code, 0);
    const records = output.trim().split('\n').map((line) => JSON.parse(line));
    assert.ok(records.some((record) => record.id === 'state' && record.success === true));
  } finally { clearTimeout(timer); }
} finally { await rm(home, { recursive: true, force: true }); }
console.log('OpenDesign/Pi compatibility checks passed');
