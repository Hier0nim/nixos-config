import { readFile } from 'node:fs/promises';
import { setTimeout as sleep } from 'node:timers/promises';

/** Wait for the daemon and update only its custom instructions. */
async function configure() {
  const base = 'http://127.0.0.1:7456';
  for (let attempt = 0; attempt < 60; attempt++) {
    try {
      const health = await fetch(`${base}/api/health`, { signal: AbortSignal.timeout(2000) });
      if (health.ok) break;
    } catch { /* The daemon may still be starting. */ }
    if (attempt === 59) throw new Error('Daemon did not become ready within 60 attempts');
    await sleep(1000);
  }
  const customInstructions = await readFile('/etc/open-design/pi-policy.md', 'utf8');
  const response = await fetch(`${base}/api/app-config`, {
    method: 'PUT', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ customInstructions }), signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) throw new Error(`Policy API returned HTTP ${response.status}`);
  const { config } = await response.json();
  if (config?.customInstructions !== customInstructions) throw new Error('Policy API did not retain instructions');
  console.log('OpenDesign is ready and its browser policy is set');
}

await configure().catch(() => {
  console.error('OpenDesign readiness or policy application failed; inspect private service logs');
  process.exitCode = 1;
});
