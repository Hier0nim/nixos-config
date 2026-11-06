# Test a built image with disposable state. Argument: docker or rootless podman.
set -euo pipefail
umask 0077
backend=${1:-docker}
case "$backend" in
  docker|podman) ;;
  *) echo "Usage: open-design-smoke [docker|podman]" >&2; exit 2 ;;
esac
state=$(mktemp -d /tmp/open-design-smoke-XXXXXXXX)
name="open-design-smoke-${state##*-}"
# Never touch the live container or its state.
cleanup() {
  "$backend" stop --time 30 "$name" >/dev/null 2>&1 || true
  "$backend" rm -f "$name" >/dev/null 2>&1 || true
  rm -rf -- "$state"
}
trap cleanup EXIT
mapping=()
if [ "$backend" = docker ]; then
  if [ "$(id -u)" -ne 0 ]; then
    echo "Run the Docker smoke helper through sudo, or choose rootless podman" >&2
    exit 1
  fi
  chown 1004:1004 "$state"
  @dockerLoader@
else
  if [ "$(id -u)" -eq 0 ]; then
    echo "Use podman as an ordinary user for this local smoke test" >&2
    exit 1
  fi
  mapping=("--userns=keep-id:uid=1004,gid=1004")
  @podmanLoader@
fi
# Use the service's mount and resource limits, without ports or external networking.
start() {
  "$backend" run -d --name "$name" --pull=never --network=none \
    "${mapping[@]}" --user 1004:1004 --read-only --cap-drop=ALL \
    --security-opt=no-new-privileges:true --memory=4g --cpus=2 \
    --pids-limit=1024 --shm-size=512m --stop-timeout=45 \
    --tmpfs=/tmp:rw,nosuid,nodev,noexec,size=1g,mode=1777 \
    --volume "$state:/state" @imageRef@ >/dev/null
  "$backend" exec --user 1004:1004 "$name" /bin/node /etc/open-design/configure.mjs
}
start
"$backend" exec --user 1004:1004 "$name" /bin/node /etc/open-design/doctor.mjs --browser
# Check that startup preserves UI choices and Pi files.
"$backend" exec --user 1004:1004 "$name" /bin/node --input-type=module -e '
  import fs from "node:fs";
  const response = await fetch("http://127.0.0.1:7456/api/app-config", {
    method: "PUT", headers: {"Content-Type":"application/json"},
    body: JSON.stringify({agentId:"pi", agentModels:{pi:{model:"default",reasoning:"high"}}})
  });
  if (!response.ok) process.exit(1);
  fs.writeFileSync("/state/.smoke-retained", "retained");
  fs.writeFileSync(process.env.PI_CODING_AGENT_DIR + "/auth.json", "{}\n", {mode:0o600});
  fs.writeFileSync(process.env.PI_CODING_AGENT_DIR + "/settings.json", "{\"theme\":\"dark\"}\n", {mode:0o600});
'
# Reuse the state after container recreation.
"$backend" stop --time 45 "$name" >/dev/null
"$backend" rm "$name" >/dev/null
start
"$backend" exec --user 1004:1004 "$name" /bin/node /etc/open-design/doctor.mjs
"$backend" exec --user 1004:1004 "$name" /bin/node --input-type=module -e '
  import assert from "node:assert/strict";
  import fs from "node:fs";
  const response = await fetch("http://127.0.0.1:7456/api/app-config");
  const {config} = await response.json();
  assert.equal(config.agentId, "pi");
  assert.equal(config.agentModels.pi.model, "default");
  assert.equal(config.agentModels.pi.reasoning, "high");
  assert.equal(fs.readFileSync("/state/.smoke-retained", "utf8"), "retained");
  assert.equal(fs.readFileSync(process.env.PI_CODING_AGENT_DIR + "/auth.json", "utf8"), "{}\n");
  assert.equal(fs.readFileSync(process.env.PI_CODING_AGENT_DIR + "/settings.json", "utf8"), "{\"theme\":\"dark\"}\n");
'
printf 'Isolated image smoke/recreation passed; no model or provider requests made.\n'
