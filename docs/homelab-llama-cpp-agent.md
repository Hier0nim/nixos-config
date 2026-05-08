# llama-cpp-agent

`llama-cpp-agent` runs `llama-swap` as the always-on lightweight proxy. Model
processes are started by `llama-swap` on demand and stopped after their
configured TTL.

## URLs

- Browser chat: `https://ai.pieczarkowo.me`
- API: `https://ai-api.pieczarkowo.me/v1`

The browser hostname is protected by the homelab Caddy auth group configured on
the service. Its root path redirects to the default model chat:

```text
/upstream/<defaultModel>/?new_chat=true#/
```

The API hostname proxies to `llama-swap` itself, not to a raw model upstream.
It is intended for OpenAI-compatible clients:

```text
OPENAI_BASE_URL=https://ai-api.pieczarkowo.me/v1
OPENAI_API_KEY=<content of /run/secrets/llama_cpp_agent_api_key>
```

## Auth Model

Raw `llama-server` processes do not receive `--api-key-file`. The llama.cpp
browser UI under `/upstream` does not send the API key for every internal
request, so upstream API-key auth can break UI routes such as `/cors-proxy` and
`/_app/version.json`.

Public API auth is handled before requests reach `llama-swap`. The packaged
`llama-swap` version in this repo does not support top-level `apiKeys`, so
Caddy checks `Authorization: Bearer <secret>` with a SOPS-rendered template.
The secret is not written to the Nix store.

## Dynamic Loading

Opening the default browser chat or sending an API request with a configured
`model` starts that model through `llama-swap`. Idle models are stopped after
`ttl`, or after `dynamicStart.idleStopMinutes` when a model-specific TTL is not
set.

Increase `idleStopMinutes` to reduce frequent unload and reload cycles for
models used often. Values around 30-60 minutes are reasonable for active use.

## Model Storage

Keep `svc.modelDir` on SSD/NVMe when possible. Dynamic loading is sensitive to
disk read speed because llama.cpp must read large GGUF files during cold starts,
especially after reboot, after idle unload, after memory pressure evicts Linux
page cache, or after the first request following a long idle period.

Repeated starts can be faster if Linux page cache still contains the model, but
that should not be relied on. SSD/NVMe improves model read time; it does not fix
RAM pressure, swapping, or insufficient memory for large models.

On `server-legion`, model files are configured under the NVMe-backed
`/var/lib/homelab/models/llm`. Media and downloads remain on the existing
HDD-backed `/data` layout.

## API Tests

```sh
API_KEY="$(sudo cat /run/secrets/llama_cpp_agent_api_key | tr -d '\r\n')"

curl -sS https://ai-api.pieczarkowo.me/v1/models \
  -H "Authorization: Bearer $API_KEY"

curl -sS https://ai-api.pieczarkowo.me/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen","messages":[{"role":"user","content":"Say hello in one short sentence."}],"max_tokens":32}'
```

## Post-Rebuild Checks

```sh
systemctl status llama-cpp-agent
journalctl -u llama-cpp-agent -b --no-pager
ss -ltnp | grep llama

API_KEY="$(sudo cat /run/secrets/llama_cpp_agent_api_key | tr -d '\r\n')"
curl -sS http://127.0.0.1:8080/v1/models -H "Authorization: Bearer $API_KEY"
curl -sS https://ai-api.pieczarkowo.me/v1/models -H "Authorization: Bearer $API_KEY"
```

Also verify:

- `https://ai.pieczarkowo.me` lands in the default model chat.
- Opening browser chat starts the default model on demand.
- API requests with `"model":"qwen"` start the model on demand.
- Idle model unload works after the configured TTL.
- Raw model ports bind only to `127.0.0.1` on the host and are not reachable
  from LAN or public networks.
- `/run` Caddy templates contain the API key, while `/nix/store` and static
  config files do not.
- Generated commands and model download units use the intended `svc.modelDir`,
  with no old HDD model path remaining.

If GGUF files already exist under an old HDD-backed model directory, move them
after rebuilding:

```sh
sudo mkdir -p /var/lib/homelab/models/llm
sudo mv /data/models/llm/*.gguf /var/lib/homelab/models/llm/
sudo chmod 0444 /var/lib/homelab/models/llm/*.gguf
```
