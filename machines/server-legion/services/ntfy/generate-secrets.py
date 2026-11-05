"""Generate ntfy's native users and separate subscriber/publisher credentials."""

import os
from pathlib import Path
import secrets
import subprocess

import bcrypt


def generate(out: Path) -> None:
    """Write root-only Clan Vars outputs without logging credentials."""
    users = []
    tokens = []
    for name in ("hieronim", "gatus"):
        password = secrets.token_urlsafe(36)
        hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt(rounds=12)).decode()
        token = subprocess.check_output(["ntfy", "token", "generate"], text=True).strip()
        users.append(f"{name}:{hashed}:user")
        tokens.append(f"{name}:{token}:homelab")
        (out / f"{name}-token").write_text(token)
        if name == "hieronim":
            (out / "hieronim-password").write_text(password)
    (out / "server.env").write_text(
        "NTFY_AUTH_USERS=" + ",".join(users) + "\n"
        "NTFY_AUTH_TOKENS=" + ",".join(tokens) + "\n"
    )
    for path in out.iterdir():
        path.chmod(0o400)


if __name__ == "__main__":
    generate(Path(os.environ["out"]))
