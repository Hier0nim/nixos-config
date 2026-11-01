"""Test the pinned Forgejo CLI and authenticated OIDC linking with synthetic identities."""

import base64
import hashlib
import http.cookiejar
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import pwd
import secrets
import shutil
import socket
import sqlite3
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

root = Path(tempfile.mkdtemp(prefix="legion-forgejo-fixture-"))
root.chmod(0o700)
children = []
client_secret = "synthetic-client-secret-in-environment-only"
codes = {}
mode = "admin"


def b64(value):
    """Encode bytes as unpadded JOSE base64url."""
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode()


def free_port():
    """Reserve an unused IPv4 loopback port number for the synthetic app."""
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


app_url = f"http://127.0.0.1:{free_port()}"
key = root / "signing.pem"
subprocess.run(
    ["openssl", "genrsa", "-out", str(key), "2048"],
    check=True,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)
modulus = (
    subprocess.check_output(
        ["openssl", "rsa", "-in", str(key), "-noout", "-modulus"],
        stderr=subprocess.DEVNULL,
    )
    .decode()
    .strip()
    .split("=")[1]
)
jwk = {
    "kty": "RSA",
    "kid": "fixture",
    "use": "sig",
    "alg": "RS256",
    "n": b64(bytes.fromhex(modulus)),
    "e": "AQAB",
}


def claims(identity):
    """Return deliberately mismatched identities and hostile role claims."""
    return {
        "sub": "subject-" + identity,
        "preferred_username": "idp-" + identity,
        "email": "nativeadmin@example.invalid"
        if identity == "unlinked"
        else identity + "@idp.invalid",
        "email_verified": True,
        "name": "IdP " + identity,
        "groups": ["admins"],
        "role": "ADMIN",
    }


class Issuer(BaseHTTPRequestHandler):
    """Serve signed synthetic OIDC, enforcing client credentials and PKCE."""

    def log_message(self, *args):
        """Do not log authorization codes or tokens."""

    def send_json(self, data, status=200):
        """Return a bounded JSON response without access logs."""
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def do_GET(self):
        """Serve discovery, keys, userinfo or the fake authorization step."""
        base = f"http://127.0.0.1:{self.server.server_port}"
        path = urllib.parse.urlparse(self.path)
        if path.path == "/.well-known/openid-configuration":
            self.send_json(
                {
                    "issuer": base,
                    "authorization_endpoint": base + "/authorize",
                    "token_endpoint": base + "/token",
                    "userinfo_endpoint": base + "/userinfo",
                    "jwks_uri": base + "/jwks",
                    "response_types_supported": ["code"],
                    "subject_types_supported": ["public"],
                    "id_token_signing_alg_values_supported": ["RS256"],
                    "token_endpoint_auth_methods_supported": ["client_secret_basic"],
                    "code_challenge_methods_supported": ["S256"],
                }
            )
        elif path.path == "/jwks":
            self.send_json({"keys": [jwk]})
        elif path.path == "/userinfo":
            self.send_json(claims(self.headers["Authorization"].split(" ")[1]))
        elif path.path == "/authorize":
            query = urllib.parse.parse_qs(path.query)
            assert query["client_id"] == ["fixture-forgejo"]
            assert query["redirect_uri"] == [app_url + "/user/oauth2/authelia/callback"]
            assert query["code_challenge_method"] == ["S256"]
            assert {"openid", "email", "profile"} <= set(query["scope"][0].split())
            code = secrets.token_urlsafe(24)
            codes[code] = (mode, query["code_challenge"][0])
            self.send_response(302)
            self.send_header(
                "Location",
                query["redirect_uri"][0]
                + "?"
                + urllib.parse.urlencode({"state": query["state"][0], "code": code}),
            )
            self.end_headers()
        else:
            self.send_json({}, 404)

    def do_POST(self):
        """Require basic client auth and the original S256 verifier."""
        form = urllib.parse.parse_qs(
            self.rfile.read(int(self.headers["Content-Length"])).decode()
        )
        expected = (
            "Basic "
            + base64.b64encode(("fixture-forgejo:" + client_secret).encode()).decode()
        )
        assert self.headers.get("Authorization") == expected
        identity, challenge = codes.pop(form["code"][0])
        assert (
            b64(hashlib.sha256(form["code_verifier"][0].encode()).digest()) == challenge
        )
        now = int(time.time())
        payload = {
            **claims(identity),
            "iss": f"http://127.0.0.1:{self.server.server_port}",
            "aud": "fixture-forgejo",
            "iat": now,
            "exp": now + 300,
        }
        signed = (
            b64(json.dumps({"alg": "RS256", "kid": "fixture"}).encode())
            + "."
            + b64(json.dumps(payload).encode())
        ).encode()
        signature = subprocess.check_output(
            ["openssl", "dgst", "-sha256", "-sign", str(key)], input=signed
        )
        self.send_json(
            {
                "access_token": identity,
                "token_type": "Bearer",
                "expires_in": 300,
                "id_token": signed.decode() + "." + b64(signature),
            }
        )


idp = ThreadingHTTPServer(("127.0.0.1", 0), Issuer)
threading.Thread(target=idp.serve_forever, daemon=True).start()
issuer = f"http://127.0.0.1:{idp.server_port}"
config = root / "app.ini"
config.write_text(f"""APP_NAME = Fixture
RUN_MODE = prod
RUN_USER = {pwd.getpwuid(os.getuid()).pw_name}
WORK_PATH = {root}
[database]
DB_TYPE = sqlite3
PATH = {root / "forgejo.db"}
[server]
DOMAIN = 127.0.0.1
HTTP_ADDR = 127.0.0.1
HTTP_PORT = {urllib.parse.urlparse(app_url).port}
ROOT_URL = {app_url}/
DISABLE_SSH = true
STATIC_ROOT_PATH = {os.environ["FORGEJO_DATA"]}
APP_DATA_PATH = {root / "data"}
[repository]
ROOT = {root / "repositories"}
[security]
INSTALL_LOCK = true
SECRET_KEY = fixture-security-key-not-production
INTERNAL_TOKEN = fixture-internal-token-not-production
[service]
DISABLE_REGISTRATION = true
REQUIRE_SIGNIN_VIEW = true
[oauth2_client]
ENABLE_AUTO_REGISTRATION = false
ACCOUNT_LINKING = login
OPENID_CONNECT_SCOPES = openid email profile
UPDATE_AVATAR = false
[log]
MODE = console
LEVEL = Error
LOGGER_ROUTER_MODE = ,
DISABLE_ROUTER_LOG = true
ENABLE_ACCESS_LOG = false
""")
binary = str(Path(os.environ["FORGEJO_PACKAGE"]) / "bin/forgejo")
base_command = [binary, "--work-path", str(root), "--config", str(config)]
env = {
    **os.environ,
    "HOME": str(root),
    "FORGEJO_WORK_DIR": str(root),
    "FORGEJO_CUSTOM": str(root / "custom"),
}


def cli(args, secret=None):
    """Run native CLI with credentials in child environment, never argv or output."""
    command = base_command + args
    child_env = {**env, **({"FORGEJO_OAUTH_CLIENT_SECRET": secret} if secret else {})}
    assert client_secret not in " ".join(command)
    result = subprocess.run(
        command,
        cwd=root,
        env=child_env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=90,
    )
    assert not secret or secret.encode() not in result.stdout + result.stderr
    if result.returncode:
        raise RuntimeError(
            "CLI failed: " + " ".join(args[:4]) + ": " + result.stderr.decode()[-1000:]
        )
    return result.stdout.decode()


def provision():
    """Run the real owned provisioning fragment with synthetic paths and issuer."""
    script = Path(os.environ["FORGEJO_PRESTART"]).read_text()
    marker = 'digest=$(sha256sum "$CREDENTIALS_DIRECTORY/oidc-client-secret")'
    script = script[script.index(marker) :]
    script = script.replace(
        "https://auth.pieczarkowo.me/.well-known/openid-configuration",
        issuer + "/.well-known/openid-configuration",
    )
    script = script.replace("--key forgejo ", "--key fixture-forgejo ")
    assert "--key forgejo " not in script
    assert "auth.pieczarkowo.me" not in script
    credentials = root / "credentials"
    credentials.mkdir(exist_ok=True, mode=0o700)
    (credentials / "oidc-client-secret").write_text(client_secret)
    default_config = root / "custom/conf/app.ini"
    default_config.parent.mkdir(parents=True, exist_ok=True)
    default_config.write_text(config.read_text())
    subprocess.run(
        ["bash", "-euo", "pipefail", "-c", script],
        env={
            **env,
            "CREDENTIALS_DIRECTORY": str(credentials),
            "PATH": str(Path(binary).parent) + ":" + env["PATH"],
        },
        cwd=root,
        check=True,
        timeout=30,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def sql(query, args=()):
    """Read only synthetic native state for identity and role assertions."""
    with sqlite3.connect(
        "file:" + str(root / "forgejo.db") + "?mode=ro", uri=True
    ) as db:
        return db.execute(query, args).fetchall()


def browser():
    """Return an isolated synthetic browser with its own cookie jar."""
    return urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar())
    )


def visit(client, path, form=None):
    """Visit local synthetic routes, optionally submitting a native HTML form."""
    request = urllib.request.Request(
        app_url + path,
        data=None if form is None else urllib.parse.urlencode(form).encode(),
        headers={}
        if form is None
        else {"Origin": app_url, "Referer": app_url + "/user/login"},
    )
    with client.open(request, timeout=20) as response:
        return response.url, response.read().decode()


def login(client, username):
    """Authenticate only a freshly created synthetic native user."""
    visit(client, "/user/login")
    url, html = visit(
        client,
        "/user/login",
        {
            "user_name": username,
            "password": "Synthetic-Native-Password-0123",
        },
    )
    assert "/user/login" not in url, (url, html[-1000:])


try:
    cli(["migrate"])
    for name, admin in [("nativeadmin", True), ("nativemember", False)]:
        cli(
            [
                "admin",
                "user",
                "create",
                "--username",
                name,
                "--email",
                name + "@example.invalid",
                "--password",
                "Synthetic-Native-Password-0123",
                "--must-change-password=false",
                "--admin=" + str(admin).lower(),
            ]
        )
    native_before = sql(
        'SELECT id,name,email,passwd,is_admin,is_active FROM "user" ORDER BY id'
    )
    flags = [
        "--name",
        "authelia",
        "--provider",
        "openidConnect",
        "--key",
        "fixture-forgejo",
        "--auto-discover-url",
        issuer + "/.well-known/openid-configuration",
        "--scopes",
        "openid",
        "--scopes",
        "email",
        "--scopes",
        "profile",
        "--skip-local-2fa",
    ]
    cli(["admin", "auth", "add-oauth", *flags], "synthetic-first-secret")
    source_id, source_json = sql(
        "SELECT id,cfg FROM login_source WHERE name=?", ("authelia",)
    )[0]
    assert json.loads(source_json)["ClientSecret"] == "synthetic-first-secret"
    cli(
        ["admin", "auth", "update-oauth", "--id", str(source_id), *flags], client_secret
    )
    assert sql("SELECT id FROM login_source WHERE name=?", ("authelia",)) == [
        (source_id,)
    ]
    settings = json.loads(
        sql("SELECT cfg FROM login_source WHERE id=?", (source_id,))[0][0]
    )
    assert settings["ClientSecret"] == client_secret
    assert not settings.get("AdminGroup") and not settings.get("GroupClaimName")
    cli(["admin", "auth", "add-oauth", "--help"], client_secret)
    provision()
    provision()
    assert sql("SELECT id FROM login_source WHERE name=?", ("authelia",)) == [
        (source_id,)
    ]
    log = (root / "server.log").open("wb")
    child = subprocess.Popen(
        base_command + ["web"], env=env, cwd=root, stdout=log, stderr=log
    )
    children.append(child)
    for attempt in range(100):
        try:
            visit(browser(), "/user/login")
            break
        except (OSError, urllib.error.URLError):
            if child.poll() is not None:
                raise RuntimeError("Synthetic server exited")
            time.sleep(0.1)
    else:
        raise RuntimeError("Synthetic server not ready")
    mode = "unlinked"
    anonymous = browser()
    visit(anonymous, "/user/oauth2/authelia")
    assert sql('SELECT count(*) FROM "user"') == [(2,)]
    assert sql("SELECT count(*) FROM external_login_user") == [(0,)]
    for username, identity in [("nativeadmin", "admin"), ("nativemember", "member")]:
        mode = identity
        client = browser()
        login(client, username)
        visit(client, "/user/oauth2/authelia")
        user_id = sql('SELECT id FROM "user" WHERE name=?', (username,))[0][0]
        assert sql(
            "SELECT user_id FROM external_login_user WHERE external_id=?",
            ("subject-" + identity,),
        ) == [(user_id,)]
        fresh = browser()
        visit(fresh, "/user/oauth2/authelia")
        url, _ = visit(fresh, "/user/settings/security")
        assert "/user/login" not in url
    assert (
        sql('SELECT id,name,email,passwd,is_admin,is_active FROM "user" ORDER BY id')
        == native_before
    )
    child.terminate()
    child.wait(timeout=10)
    idp.shutdown()
    idp.server_close()
    provision()
    child = subprocess.Popen(
        base_command + ["web"], env=env, cwd=root, stdout=log, stderr=log
    )
    children.append(child)
    for attempt in range(100):
        try:
            visit(browser(), "/user/login")
            break
        except (OSError, urllib.error.URLError):
            if child.poll() is not None:
                raise RuntimeError(
                    "Native login cannot start while the issuer is offline"
                )
            time.sleep(0.1)
    else:
        raise RuntimeError("Native login not ready while the issuer is offline")
    login(browser(), "nativeadmin")
    print(
        json.dumps(
            {
                "native_env_secret_add_update_idempotence": True,
                "pkce_s256_and_basic_client_auth": True,
                "no_email_autolink_or_registration": True,
                "authenticated_existing_account_linking_with_mismatched_email": True,
                "native_ids_emails_passwords_admin_flags_preserved": True,
                "idp_admin_claim_does_not_elevate_basic_member": True,
                "new_browser_oidc_signin": True,
                "native_login_and_source_update_survive_issuer_outage": True,
            }
        )
    )
finally:
    for child in reversed(children):
        child.terminate()
        try:
            child.wait(timeout=10)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
    idp.shutdown()
    idp.server_close()
    if os.environ.get("KEEP_FIXTURE"):
        print("Synthetic fixture retained:", root)
    else:
        shutil.rmtree(root)
