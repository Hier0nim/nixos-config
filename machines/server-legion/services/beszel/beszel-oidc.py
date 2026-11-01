"""Configure Beszel's native OIDC provider using its existing bootstrap credential."""

import hmac
import json
import os
from pathlib import Path
import shlex
import sqlite3
import sys
import time
import urllib.error
import urllib.request


def request(origin, path, token="", payload=None, method=None):
    """Call the local management API without logging credentials or response bodies."""
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = token
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(origin + path, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=10) as response:
        return json.load(response)


def configure(settings):
    """Reconcile only the owned provider; preserve users and unrelated auth settings."""
    credentials = Path(os.environ["CREDENTIALS_DIRECTORY"])
    environment = {}
    for line in (credentials / "hub.env").read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        key, separator, value = line.partition("=")
        if separator:
            parsed = shlex.split(value)
            if len(parsed) != 1:
                raise ValueError("Unsupported bootstrap environment syntax")
            environment[key.strip()] = parsed[0]
    origin = settings["origin"]
    for attempt in range(60):
        try:
            request(origin, "/api/health")
            break
        except (OSError, urllib.error.URLError):
            if attempt == 59:
                raise RuntimeError("Beszel did not become ready") from None
            time.sleep(1)
    # This is PocketBase's existing management identity, not a household user's session.
    auth = request(origin, "/api/collections/_superusers/auth-with-password", payload={
        "identity": environment.get("BESZEL_HUB_USER_EMAIL", environment.get("USER_EMAIL")),
        "password": environment.get("BESZEL_HUB_USER_PASSWORD", environment.get("USER_PASSWORD")),
    })
    token = auth["token"]
    collection = request(origin, "/api/collections/users", token)
    if collection["createRule"] is not None or not collection["passwordAuth"]["enabled"]:
        raise RuntimeError("Unexpected Beszel registration/password policy")
    provider = dict(settings["provider"])
    provider["clientSecret"] = (credentials / "client-secret").read_text().strip()
    if not provider["clientSecret"]:
        raise RuntimeError("Empty OIDC credential")
    oauth = collection["oauth2"]
    if any(item["name"] != provider["name"] for item in oauth["providers"]):
        raise RuntimeError("Unmanaged Beszel OAuth provider; refusing to replace it")
    desired = {"enabled": True, "providers": [provider], "mappedFields": {
        "id": "", "name": "", "username": "", "avatarURL": "",
    }}
    # PocketBase deliberately redacts provider secrets from its management API.
    with sqlite3.connect(Path(settings["database"]).as_uri() + "?mode=ro", uri=True) as db:
        options = json.loads(db.execute(
            "SELECT options FROM _collections WHERE name = ?", ("users",)
        ).fetchone()[0])
    matching_secret = any(
        item["name"] == provider["name"]
        and hmac.compare_digest(item.get("clientSecret", ""), provider["clientSecret"])
        for item in options["oauth2"]["providers"]
    )
    visible_keys = provider.keys() - {"clientSecret"}
    normalized = dict(oauth)
    normalized["providers"] = [
        {key: item.get(key) for key in visible_keys} for item in oauth["providers"]
    ]
    visible_desired = dict(desired, providers=[{key: provider[key] for key in visible_keys}])
    if normalized == visible_desired and matching_secret:
        print("Beszel OIDC configuration unchanged")
        return False
    updated = request(origin, "/api/collections/users", token,
                      {"oauth2": desired}, "PATCH")
    for key in collection:
        if key not in {"oauth2", "updated"} and updated.get(key) != collection[key]:
            raise RuntimeError("Unexpected unrelated Beszel collection change")
    print("Beszel OIDC configuration applied")
    return True


if __name__ == "__main__":
    try:
        configure(json.loads(Path(sys.argv[1]).read_text()))
    except Exception:
        # PocketBase validation errors may contain submitted client credentials.
        raise SystemExit("Beszel OIDC setup failed; inspect native policy and credential availability") from None
