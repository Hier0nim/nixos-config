"""Write a random OIDC client secret and its Argon2id hash to Clan's output directory."""

import os
from pathlib import Path
import secrets

from argon2 import PasswordHasher, Type

os.umask(0o077)
secret = secrets.token_urlsafe(48)
hasher = PasswordHasher(
    time_cost=3,
    memory_cost=65536,
    parallelism=4,
    hash_len=32,
    salt_len=16,
    type=Type.ID,
)
output = Path(os.environ["out"])
(output / "client-secret").write_text(secret)
(output / "client-hash").write_text(hasher.hash(secret))
for path in output.iterdir():
    path.chmod(0o400)
