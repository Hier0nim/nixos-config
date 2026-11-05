"""Write service-specific runtime secrets after generating the OIDC client pair."""

import json
import os
from pathlib import Path
import secrets
import shlex
import sys


def generate(out: Path, app: str, domain: str) -> None:
    """Create environment files for the named app, never including values in argv."""
    client = (out / "client-secret").read_text().strip()
    key = secrets.token_hex(32)
    if app == "paperless":
        provider = {"openid_connect": {
            "OAUTH_PKCE_ENABLED": False,
            "APPS": [{"provider_id": "authelia", "name": "Authelia", "client_id": app,
                      "secret": client, "settings": {"server_url": f"https://auth.{domain}/.well-known/openid-configuration"}}],
        }}
        env = {"PAPERLESS_SECRET_KEY": key, "PAPERLESS_SOCIALACCOUNT_PROVIDERS": json.dumps(provider)}
        # paperless-manage sources this file as shell code as well as systemd reading it.
        text = "".join(f"{k}={shlex.quote(v)}\n" for k, v in env.items())
    elif app == "mealie":
        (out / "app-secret").write_text(key)
        (out / "session-secret").write_text(secrets.token_hex(32))
        text = f"OIDC_CLIENT_SECRET={client}\n"
    elif app == "donetick":
        text = f"DT_OAUTH2_CLIENT_SECRET={client}\nDT_JWT_SECRET={key}\n"
    else:
        raise ValueError("Unsupported household app")
    (out / "environment").write_text(text)
    for path in out.iterdir():
        path.chmod(0o400)


if __name__ == "__main__":
    generate(Path(os.environ["out"]), sys.argv[1], sys.argv[2])
