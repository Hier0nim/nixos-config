"""Exercise pinned Actual/Caddy with synthetic state, never production credentials."""

import base64
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import socket
import sqlite3
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

root = Path(tempfile.mkdtemp(prefix="legion-actual-header-fixture-"))
os.chmod(root, 0o700)
password = "synthetic-fixture-password-not-production"
(root / "password").write_text(password)
os.chmod(root / "password", 0o600)


def port():
    """Choose an ephemeral loopback listener for a synthetic service."""
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


backend, public, private = port(), port(), port()


def b64(value):
    """Encode a JWT component without base64 padding."""
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode()


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
codes = {}


def claims(user):
    """Supply synthetic admin claims that must not promote a native BASIC user."""
    return {
        "sub": user,
        "preferred_username": user,
        "email": user + "@example.invalid",
        "name": user,
        "groups": ["admins"],
        "role": "ADMIN",
    }


class Discovery(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        base = "http://127.0.0.1:" + str(self.server.server_port)
        data = {
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
        if self.path == "/userinfo":
            data = claims(self.headers["Authorization"].split(" ")[1])
        elif self.path != "/" + ".well-known/openid-configuration":
            data = {"keys": [jwk]}
        self.respond(data)

    def respond(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        body = urllib.parse.parse_qs(
            self.rfile.read(int(self.headers["Content-Length"])).decode()
        )
        code = body["code"][0]
        user, challenge = codes[code]
        assert (
            b64(hashlib.sha256(body["code_verifier"][0].encode()).digest()) == challenge
        )
        issuer = "http://127.0.0.1:" + str(self.server.server_port)
        now = int(time.time())
        payload = {
            **claims(user),
            "iss": issuer,
            "aud": "synthetic-actual",
            "iat": now,
            "exp": now + 300,
        }
        message = (
            b64(json.dumps({"alg": "RS256", "kid": "fixture"}).encode())
            + "."
            + b64(json.dumps(payload).encode())
        ).encode()
        signature = subprocess.check_output(
            ["openssl", "dgst", "-sha256", "-sign", str(key)], input=message
        )
        self.respond(
            {
                "access_token": user,
                "token_type": "Bearer",
                "expires_in": 300,
                "id_token": message.decode() + "." + b64(signature),
            }
        )


idp = ThreadingHTTPServer(("127.0.0.1", 0), Discovery)
threading.Thread(target=idp.serve_forever, daemon=True).start()
config = {
    "hostname": "127.0.0.1",
    "port": backend,
    "dataDir": str(root / "data"),
    "serverFiles": str(root / "server-files"),
    "userFiles": str(root / "user-files"),
    "loginMethod": "header",
    "allowedLoginMethods": ["openid", "header"],
    "enforceOpenId": True,
    "trustedAuthProxies": ["127.0.0.1/32"],
    "userCreationMode": "manual",
    "token_expiration": "openid-provider",
}
for directory in ["data", "server-files", "user-files", "admin"]:
    (root / directory).mkdir(mode=0o700)
(root / "config.json").write_text(json.dumps(config))
(root / "Caddyfile").write_text(
    """{
 admin unix//ADMIN_SOCKET
 auto_https off
}
http://127.0.0.1:PUBLIC {
 reverse_proxy 127.0.0.1:BACKEND {
  header_up -X-Actual-Password
 }
}
http://127.0.0.1:PRIVATE {
 reverse_proxy 127.0.0.1:BACKEND {
  header_up X-Actual-Password "{file.PASSWORD_FILE}"
 }
}
""".replace("PUBLIC", str(public))
    .replace("PRIVATE", str(private))
    .replace("BACKEND", str(backend))
    .replace("PASSWORD_FILE", str(root / "password"))
    .replace("ADMIN_SOCKET", str(root / "admin/admin.sock"))
)
actual = Path(os.environ["ACTUAL_PACKAGE"]) / "bin/actual-server"
caddy = Path(os.environ["CADDY_PACKAGE"]) / "bin/caddy"
children = []


def request(p, path, body=None, headers=None, method=None):
    req = urllib.request.Request(
        "http://127.0.0.1:" + str(p) + path,
        data=None if body is None else json.dumps(body).encode(),
        headers={"Content-Type": "application/json", **(headers or {})},
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        return e.code, json.load(e)


def ok(result):
    assert result[0] == 200 and result[1]["status"] == "ok", result
    return result[1].get("data")


def login(p, extra=None):
    return request(
        p, "/account/login", {"password": password, "loginMethod": "password"}, extra
    )


try:
    for executable, args, env, name in [
        (
            actual,
            [],
            {**os.environ, "ACTUAL_CONFIG_PATH": str(root / "config.json")},
            "actual",
        ),
        (
            caddy,
            ["run", "--config", str(root / "Caddyfile"), "--adapter", "caddyfile"],
            os.environ,
            "caddy",
        ),
    ]:
        log = open(root / (name + ".log"), "wb")
        children.append(
            subprocess.Popen(
                [str(executable), *args],
                cwd=root,
                env={
                    **env,
                    "XDG_CONFIG_HOME": str(root / "xdg-config"),
                    "XDG_DATA_HOME": str(root / "xdg-data"),
                },
                stdout=log,
                stderr=log,
            )
        )
        log.close()
    for attempt in range(100):
        try:
            request(public, "/account/needs-bootstrap")
            break
        except (OSError, ValueError):
            time.sleep(0.25)
    else:
        raise AssertionError("fixture startup failed; private logs in " + str(root))
    ok(request(backend, "/account/bootstrap", {"password": password}))
    first = ok(login(private))["token"]
    dbpath = root / "server-files/account.sqlite"
    with sqlite3.connect(dbpath) as db:
        identity = db.execute("SELECT id FROM users WHERE user_name='' ").fetchone()[0]
        original_hash = db.execute(
            "SELECT extra_data FROM auth WHERE method='password'"
        ).fetchone()[0]
        budget = "c4d0147d-83fd-41df-8ea0-45b4dc3d51cf"
        group = "ac7d11c3-43a3-4905-93c0-f953e76a1312"
    oidc = {
        "issuer": "http://127.0.0.1:" + str(idp.server_port),
        "client_id": "synthetic-actual",
        "client_secret": "synthetic-client-secret-not-production",
        "server_hostname": "http://127.0.0.1:" + str(public),
    }
    config["openId"] = {
        ("discoveryURL" if key == "issuer" else key): value
        for key, value in oidc.items() if key != "client_secret"
    }
    (root / "config.json").write_text(json.dumps(config))
    (root / "client-secret").write_text(oidc["client_secret"])
    helper = [
        str(Path(os.environ["NODE_PACKAGE"]) / "bin/node"),
        str(
            actual.parent.parent
            / "lib/actual/packages/sync-server/scripts/enable-openid.js"
        ),
    ]
    helper_env = {
        **os.environ,
        "ACTUAL_CONFIG_PATH": str(root / "config.json"),
        "ACTUAL_OPENID_CLIENT_SECRET_FILE": str(root / "client-secret"),
    }
    # Only synthetic credentials are used in this fixture's helper output.
    subprocess.run(helper, env=helper_env, cwd=root, check=True)
    subprocess.run(
        [
            str(caddy),
            "reload",
            "--config",
            str(root / "Caddyfile"),
            "--adapter",
            "caddyfile",
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    info = ok(request(public, "/account/needs-bootstrap"))
    assert (
        info["loginMethod"] == "openid"
        and info["multiuser"]
        and [x["method"] for x in info["availableLoginMethods"]] == ["openid"]
    )
    with sqlite3.connect(dbpath) as db:
        assert not db.execute(
            "SELECT token FROM sessions WHERE token=?", (first,)
        ).fetchone()
    for extra in [
        None,
        {"X-Actual-Password": password},
        {"x-actual-password": password},
    ]:
        code, result = login(public, extra)
        assert (
            code in (200, 400)
            and result["status"] == "error"
            and result["reason"] == "invalid-header"
        ), (code, result)
    fresh = ok(login(private))["token"]
    assert fresh != first
    subprocess.run(
        helper,
        env=helper_env,
        cwd=root,
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    with sqlite3.connect(dbpath) as db:
        assert db.execute(
            "SELECT token FROM sessions WHERE token=?", (fresh,)
        ).fetchone()
    with sqlite3.connect(dbpath) as db:
        assert (
            db.execute("SELECT id FROM users WHERE user_name='' ").fetchone()[0]
            == identity
        )
        assert (
            db.execute(
                "SELECT extra_data FROM auth WHERE method='password'"
            ).fetchone()[0]
            == original_hash
        )
        assert (
            db.execute(
                "SELECT user_id FROM sessions WHERE token=?", (fresh,)
            ).fetchone()[0]
            == identity
        )
    auth = ok(
        request(
            public,
            "/account/login",
            {
                "loginMethod": "openid",
                "returnUrl": "http://127.0.0.1:" + str(public) + "/",
            },
        )
    )
    assert auth["returnUrl"].startswith(oidc["issuer"] + "/authorize?")

    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args, **kwargs):
            return None

    tokens = {}
    for user in ["fixture-hieronim", "fixture-sarcia"]:
        if user == "fixture-sarcia":
            member = {
                "userName": user,
                "role": "BASIC",
                "displayName": "Synthetic regular user",
                "enabled": True,
            }
            member["id"] = ok(
                request(private, "/admin/users", member, {"X-ACTUAL-TOKEN": fresh})
            )["id"]
            # Pinned create endpoint omits role; the native PATCH endpoint sets it correctly.
            ok(
                request(
                    private,
                    "/admin/users",
                    member,
                    {"X-ACTUAL-TOKEN": fresh},
                    method="PATCH",
                )
            )
        authorization = ok(
            request(
                public,
                "/account/login",
                {
                    "loginMethod": "openid",
                    "returnUrl": "http://127.0.0.1:" + str(public),
                },
            )
        )
        params = urllib.parse.parse_qs(
            urllib.parse.urlsplit(authorization["returnUrl"]).query
        )
        codes[user] = (user, params["code_challenge"][0])
        callback = (
            "http://127.0.0.1:"
            + str(public)
            + "/openid/callback?"
            + urllib.parse.urlencode({"state": params["state"][0], "code": user})
        )
        try:
            urllib.request.build_opener(NoRedirect).open(callback, timeout=15)
            raise AssertionError("missing callback redirect")
        except urllib.error.HTTPError as response:
            assert response.code == 302, "callback failed in private fixture"
            tokens[user] = urllib.parse.parse_qs(
                urllib.parse.urlsplit(response.headers["Location"]).query
            )["token"][0]
    with sqlite3.connect(dbpath) as db:
        human = db.execute(
            "SELECT id,owner,role FROM users WHERE user_name='fixture-hieronim'"
        ).fetchone()
        regular = db.execute(
            "SELECT id,owner,role FROM users WHERE user_name='fixture-sarcia'"
        ).fetchone()
        assert human[1:] == (1, "ADMIN") and regular[1:] == (0, "BASIC")
        assert (
            0
            < db.execute(
                "SELECT expires_at FROM sessions WHERE token=?",
                (tokens["fixture-hieronim"],),
            ).fetchone()[0]
            - time.time()
            < 3600
        )
        # Seed the current owner/budget relationship, not the completed ownership migration.
        db.execute(
            "INSERT INTO files(id,group_id,sync_version,name,owner) VALUES(?,?,?,?,?)",
            (budget, group, 3, "Synthetic shared budget", human[0]),
        )

    def budgets(token):
        return ok(
            request(public, "/sync/list-user-files", headers={"X-ACTUAL-TOKEN": token})
        )

    assert budgets(tokens["fixture-sarcia"]) == []
    assert (
        request(
            public,
            "/admin/users",
            {"userName": "must-not-be-created"},
            {"X-ACTUAL-TOKEN": tokens["fixture-sarcia"]},
        )[0]
        == 403
    )
    ok(
        request(
            public,
            "/admin/access",
            {"fileId": budget, "userId": regular[0]},
            {"X-ACTUAL-TOKEN": tokens["fixture-hieronim"]},
        )
    )
    assert [f["fileId"] for f in budgets(tokens["fixture-sarcia"])] == [budget]
    assert [f["fileId"] for f in budgets(fresh)] == [budget]
    adapted = subprocess.check_output(
        [
            str(caddy),
            "adapt",
            "--config",
            str(root / "Caddyfile"),
            "--adapter",
            "caddyfile",
        ],
        stderr=subprocess.DEVNULL,
    )
    assert password.encode() not in adapted and b"{file." in adapted
    print("PASS Actual public authentication, private automation, idempotent setup and native owner/BASIC budget access")
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
