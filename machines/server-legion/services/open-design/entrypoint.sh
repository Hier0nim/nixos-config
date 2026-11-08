#!/bin/bash
# Prepare state, then start the daemon. No arguments.
set -euo pipefail
umask 0077
: "${OD_DATA_DIR:?}" "${HOME:?}" "${PI_CODING_AGENT_DIR:?}" "${XDG_CACHE_HOME:?}"
mkdir -p "$OD_DATA_DIR" "$HOME" "$PI_CODING_AGENT_DIR" "$XDG_CACHE_HOME"
chmod 0700 "$OD_DATA_DIR" "$HOME" "$PI_CODING_AGENT_DIR" "$XDG_CACHE_HOME"
# Replace only our policy, not Pi's credentials, settings or project instructions.
policy=$(mktemp "$PI_CODING_AGENT_DIR/.AGENTS.md.XXXXXXXX")
trap 'rm -f "$policy"' EXIT
cp /etc/open-design/pi-policy.md "$policy"
chmod 0600 "$policy"
mv -f "$policy" "$PI_CODING_AGENT_DIR/AGENTS.md"
trap - EXIT
mkdir -p "$PI_CODING_AGENT_DIR/skills/unslop"
ln -sfn /etc/open-design/skills/unslop/SKILL.md "$PI_CODING_AGENT_DIR/skills/unslop/SKILL.md"
exec /bin/node /app/apps/daemon/dist/cli.js --no-open
