"""Exercise native Beszel provisioning and authenticated linking with synthetic identities."""

import base64
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import importlib.util
import json
import os
from pathlib import Path
import secrets
import socket
import sqlite3
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

root = Path(tempfile.mkdtemp(prefix="legion-beszel-fixture-"))
root.chmod(0o700)
children = []
codes = {}
mode = "admin"
client_secret = "synthetic-beszel-client-secret"


def b64(value):
    """Encode JOSE and PKCE byte strings."""
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode()


def free_port():
    """Choose a private synthetic listener port."""
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


app_url = f"http://127.0.0.1:{free_port()}"
callback = app_url + "/__sso/link"
key = root / "signing.pem"
subprocess.run(["openssl", "genrsa", "-out", str(key), "2048"], check=True,
               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def claims(identity):
    """Supply mismatched profile fields and hostile native-admin claims."""
    return {"sub": "subject-" + identity, "email": identity + "@idp.invalid",
            "email_verified": True, "name": "IdP rename", "role": "admin",
            "groups": ["admin"], "preferred_username": "different-" + identity}


class Issuer(BaseHTTPRequestHandler):
    """Serve signed OIDC with enforced basic client auth and S256."""

    def log_message(self, *args):
        """Keep synthetic authorization material out of logs."""

    def reply(self, value, status=200):
        """Send a JSON response."""
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(value).encode())

    def do_GET(self):
        """Simulate a user authorization and a token-bound profile response."""
        path = urllib.parse.urlparse(self.path)
        if path.path == "/userinfo":
            identity = self.headers.get("Authorization", "").removeprefix("Bearer ")
            self.reply(claims(identity))
        elif path.path == "/authorize":
            query = urllib.parse.parse_qs(path.query)
            assert query["client_id"] == ["beszel"]
            assert query["redirect_uri"] == [callback]
            assert query["code_challenge_method"] == ["S256"]
            assert {"openid", "email", "profile"} <= set(query["scope"][0].split())
            code = secrets.token_urlsafe(24)
            codes[code] = (mode, query["code_challenge"][0])
            self.reply({"code": code, "state": query["state"][0]})
        else:
            self.reply({}, 404)

    def do_POST(self):
        """Check both confidential client identity and the original verifier."""
        form = urllib.parse.parse_qs(self.rfile.read(int(self.headers["Content-Length"])).decode())
        expected = "Basic " + base64.b64encode(("beszel:" + client_secret).encode()).decode()
        if self.headers.get("Authorization") != expected:
            return self.reply({"error": "invalid_client"}, 401)
        identity, challenge = codes.pop(form["code"][0])
        if b64(hashlib.sha256(form["code_verifier"][0].encode()).digest()) != challenge:
            return self.reply({"error": "invalid_grant"}, 400)
        now = int(time.time())
        payload = {**claims(identity), "iss": issuer_url, "aud": "beszel", "iat": now, "exp": now + 300}
        signed = (b64(b'{"alg":"RS256"}') + "." + b64(json.dumps(payload).encode())).encode()
        signature = subprocess.check_output(["openssl", "dgst", "-sha256", "-sign", str(key)], input=signed)
        self.reply({"access_token": identity, "token_type": "Bearer", "expires_in": 300,
                    "id_token": signed.decode() + "." + b64(signature)})


def api(path, body=None, token="", method=None, expected=200):
    """Call the synthetic instance, checking status without logging tokens."""
    req = urllib.request.Request(app_url + path,
        data=None if body is None else json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "Authorization": token}, method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            status, value = response.status, json.load(response)
    except urllib.error.HTTPError as error:
        status, value = error.code, json.load(error)
    assert status == expected, (path, status, expected)
    return value


def native_login(email, password):
    """Authenticate only a synthetic native account."""
    return api("/api/collections/users/auth-with-password", {"identity": email, "password": password})


def exchange(identity, token="", verifier_override=None, expected=200):
    """Complete an OIDC flow optionally authorized by an existing native session."""
    global mode
    mode = identity
    provider = api("/api/collections/users/auth-methods")["oauth2"]["providers"][0]
    assert provider["name"] == "oidc" and provider["codeChallengeMethod"] == "S256"
    url = urllib.parse.urlparse(provider["authURL"])
    query = urllib.parse.parse_qs(url.query)
    query["redirect_uri"] = [callback]
    with urllib.request.urlopen(urllib.parse.urlunparse(url._replace(query=urllib.parse.urlencode(query, doseq=True)))) as response:
        result = json.load(response)
    return api("/api/collections/users/auth-with-oauth2", {
        "provider": "oidc", "code": result["code"],
        "codeVerifier": verifier_override or provider["codeVerifier"], "redirectURL": callback,
        "createData": {"role": "admin"},
    }, token=token, expected=expected)


issuer = ThreadingHTTPServer(("127.0.0.1", 0), Issuer)
issuer_url = f"http://127.0.0.1:{issuer.server_port}"
threading.Thread(target=issuer.serve_forever, daemon=True).start()
try:
    credentials = root / "credentials"
    credentials.mkdir(mode=0o700)
    (credentials / "hub.env").write_text('USER_EMAIL="nativeadmin@example.invalid"\nUSER_PASSWORD="Synthetic-password-only-123"\n')
    (credentials / "client-secret").write_text(client_secret)
    env = dict(os.environ, USER_EMAIL="nativeadmin@example.invalid", USER_PASSWORD="Synthetic-password-only-123",
               CREDENTIALS_DIRECTORY=str(credentials))
    log = (root / "beszel.log").open("w")
    child = subprocess.Popen([os.environ["BESZEL_PACKAGE"] + "/bin/beszel-hub", "serve",
                              "--http=" + app_url.removeprefix("http://")], cwd=root, env=env, stdout=log, stderr=log)
    children.append(child)
    for attempt in range(120):
        try:
            api("/api/health")
            break
        except urllib.error.URLError:
            assert child.poll() is None, "Synthetic Beszel exited"
            time.sleep(0.1)
    management = api("/api/collections/_superusers/auth-with-password", {
        "identity": "nativeadmin@example.invalid", "password": "Synthetic-password-only-123"})["token"]
    admin = native_login("nativeadmin@example.invalid", "Synthetic-password-only-123")
    admin_id = admin["record"]["id"]
    api("/api/collections/users/records/" + admin_id, {"role": "admin"}, management, "PATCH")
    basic = api("/api/collections/users/records", {"email": "nativebasic@example.invalid",
        "password": "Synthetic-basic-password-123", "passwordConfirm": "Synthetic-basic-password-123",
        "verified": True, "role": "user", "name": "Original basic"}, management)
    basic_id = basic["id"]
    db_path = root / "beszel_data/data.db"

    def rows():
        """Snapshot all native identity and authentication fields."""
        with sqlite3.connect(db_path) as db:
            return db.execute("SELECT * FROM users ORDER BY id").fetchall()

    before = rows()
    settings = {"origin": app_url, "database": str(db_path), "provider": {"name": "oidc", "displayName": "Authelia", "clientId": "beszel",
        "authURL": issuer_url + "/authorize", "tokenURL": issuer_url + "/token", "userInfoURL": issuer_url + "/userinfo", "pkce": True}}
    spec = importlib.util.spec_from_file_location("configure", os.environ["BESZEL_PROVISIONER"])
    provisioner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(provisioner)
    os.environ["CREDENTIALS_DIRECTORY"] = str(credentials)
    assert provisioner.configure(settings)
    assert not provisioner.configure(settings)
    assert rows() == before
    # Anonymous mismatched IdP identities cannot register a duplicate account.
    exchange("unlinked", expected=403)
    assert rows() == before
    exchange("admin", admin["token"], "wrong-verifier", expected=400)
    assert rows() == before
    linked = exchange("admin", admin["token"])
    assert linked["record"]["id"] == admin_id and linked["record"]["role"] == "admin"
    assert linked["record"]["email"] == "nativeadmin@example.invalid"
    assert rows() == before
    # With the native relation in place, a fresh browser needs no password.
    assert exchange("admin")["record"]["id"] == admin_id
    native_basic = native_login("nativebasic@example.invalid", "Synthetic-basic-password-123")
    linked_basic = exchange("basic", native_basic["token"])
    assert linked_basic["record"]["id"] == basic_id and linked_basic["record"]["role"] == "user"
    assert exchange("basic")["record"]["role"] == "user"
    assert rows() == before
    with sqlite3.connect(db_path) as db:
        links = db.execute("SELECT provider,providerId,recordRef FROM _externalAuths ORDER BY providerId").fetchall()
    assert links == [("oidc", "subject-admin", admin_id), ("oidc", "subject-basic", basic_id)]
    issuer.shutdown()
    assert not provisioner.configure(settings)
    child.terminate()
    child.wait(timeout=10)
    child = subprocess.Popen([os.environ["BESZEL_PACKAGE"] + "/bin/beszel-hub", "serve",
                              "--http=" + app_url.removeprefix("http://")], cwd=root, env=env, stdout=log, stderr=log)
    children.append(child)
    for attempt in range(100):
        try:
            assert native_login("nativeadmin@example.invalid", "Synthetic-password-only-123")["record"]["id"] == admin_id
            break
        except urllib.error.URLError:
            time.sleep(0.1)
    assert rows() == before
    print("PASS native Beszel management setup/idempotence, S256/basic, original-account linking, no registration/profile/role changes, fresh SSO and offline password boot")
finally:
    for child in children:
        if child.poll() is None:
            child.terminate()
            child.wait(timeout=10)
