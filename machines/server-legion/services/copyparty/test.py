"""Test the deployed Copyparty configuration, native clients and browser identity boundary."""

import base64
import http.client
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

root = Path(tempfile.mkdtemp(prefix="legion-copyparty-fixture-"))
root.chmod(0o700)
settings = json.loads(Path(os.environ["COPYPARTY_TEST_CONFIG"]).read_text())
children = []
passwords = {name: "synthetic-" + name + "-password" for name in ["admin", "hieronim", "sarcia"]}
proof = "x-copyparty-proof-" + "1" * 64
calls = {"auth": 0}


def free_port():
    """Choose a loopback-only synthetic listener."""
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


backend_port, proxy_port = free_port(), free_port()
state = root / "state"
state.mkdir()
nas = root / "nas"
for name in ["shared", "hieronim", "sarcia"]:
    path = nas / name
    path.mkdir(parents=True)
    (path / "original.txt").write_text("Original synthetic " + name + " data")
credentials = root / "credentials"
credentials.mkdir(mode=0o700)
(credentials / "idp-header-name").write_text(proof)
(credentials / "copyparty-idp-proxy").write_text("header_up " + proof + " 1\n")
env = dict(os.environ, XDG_CONFIG_HOME=str(state), CREDENTIALS_DIRECTORY=str(credentials), HOME=str(root))
binary = os.environ["COPYPARTY_PACKAGE"] + "/bin/copyparty"


def request(path, headers=None, method="GET", body=None, direct=False):
    """Make a synthetic client request without printing password-equivalent tokens."""
    connection = http.client.HTTPConnection("127.0.0.1", backend_port if direct else proxy_port, timeout=15)
    connection.request(method, path, body, {"Host": f"pliki.test:{proxy_port}", **(headers or {})})
    response = connection.getresponse()
    result = response.status, dict(response.getheaders()), response.read()
    connection.close()
    return result


def basic(name, password=None):
    """Build synthetic native Basic credentials."""
    value = name + ":" + (password or passwords[name])
    return {"Authorization": "Basic " + base64.b64encode(value.encode()).decode()}


def start_backend(config):
    """Run the pinned backend with isolated salts, sessions and payloads."""
    log = (root / "copyparty.log").open("ab")
    child = subprocess.Popen([binary, "-c", str(config)], cwd=root, env=env, stdout=log, stderr=log)
    children.append(child)
    for attempt in range(200):
        assert child.poll() is None, "Synthetic Copyparty exited"
        try:
            request("/", direct=True)
            return child
        except OSError:
            time.sleep(0.05)
    raise RuntimeError("Synthetic backend did not start")


def stop(child):
    """Wait for the synthetic backend to shut down."""
    child.terminate()
    child.wait(timeout=30)


def sessions():
    """Read native session rows only in this synthetic fixture."""
    with sqlite3.connect(state / "copyparty/sessions.db") as db:
        return dict(db.execute("SELECT un,si FROM us"))


class Auth(BaseHTTPRequestHandler):
    """Stand in for forward-auth admission, not an actual household session."""

    def log_message(self, *args):
        """Suppress synthetic access logs."""

    def do_GET(self):
        """Return a trusted canonical username only for the synthetic auth cookie."""
        calls["auth"] += 1
        assert self.headers.get("Authorization") is None
        assert self.headers.get("Proxy-Authorization") is None
        assert self.headers.get("Remote-User") is None
        user = self.headers.get("Cookie", "").split("fixture-auth=", 1)[-1].split(";", 1)[0]
        allowed = user in ["hieronim", "sarcia", "admin", "unknown"]
        self.send_response(200 if allowed else 401)
        if allowed:
            self.send_header("Remote-User", user)
        self.send_header("Content-Length", "0")
        self.end_headers()


auth = ThreadingHTTPServer(("127.0.0.1", 0), Auth)
threading.Thread(target=auth.serve_forever, daemon=True).start()
try:
    # Execute the exact production preStart, substituting only isolated runtime paths.
    runtime = root / "runtime.conf"
    script = settings["preStart"].replace("/run/copyparty/copyparty.conf", str(runtime))
    for name, original in settings["passwords"].items():
        path = credentials / (name + "-password")
        path.write_text(passwords[name])
        script = script.replace(original, str(path))
    subprocess.run(["bash", "-euc", script], cwd=root, env=env, check=True)
    script = settings["caddyPreStart"].replace("/run/caddy/copyparty-idp.caddy", str(root / "proof.caddy"))
    subprocess.run(["bash", "-euc", script], cwd=root, env=env, check=True)
    assert (root / "proof.caddy").stat().st_mode & 0o777 == 0o400
    text = runtime.read_text().replace("p: 3923", "p: " + str(backend_port))
    for name in ["shared", "hieronim", "sarcia"]:
        text = text.replace("/data/nas/" + name, str(nas / name))
    assert "@@COPYPARTY_IDP_KEY@@" not in text and proof in text
    assert "\nsarka:" not in text and "/nas/sarka" not in text
    runtime.write_text(text)
    child = start_backend(runtime)
    native_sessions = sessions()
    assert set(native_sessions) == {"admin", "hieronim", "sarcia"}

    admin_address = "unix/" + str(root / "admin.sock")
    caddyfile = "{\n admin " + admin_address + "\n auto_https off\n}\n"
    route = settings["route"].replace("http://127.0.0.1:3923", f"http://127.0.0.1:{backend_port}")
    route = route.replace("127.0.0.1:9091", f"127.0.0.1:{auth.server_port}")
    route = route.replace("/run/caddy/copyparty-idp.caddy", str(root / "proof.caddy"))
    caddyfile += f"http://pliki.test:{proxy_port} {{\n{route}\n}}\n"
    (root / "Caddyfile").write_text(caddyfile)
    log = (root / "caddy.log").open("wb")
    caddy = subprocess.Popen(["caddy", "run", "--config", str(root / "Caddyfile"), "--adapter", "caddyfile"],
                             cwd=root, env=env, stdout=log, stderr=log)
    children.append(caddy)
    for attempt in range(100):
        assert caddy.poll() is None, "Synthetic Caddy exited"
        try:
            request("/")
            break
        except OSError:
            time.sleep(0.05)
    # ExecReload has no startup credentials. The protected runtime import must still adapt/reload.
    (credentials / "copyparty-idp-proxy").rename(root / "unmounted-startup-proof")
    reload_credentials = root / "empty-reload-credentials"
    reload_credentials.mkdir(mode=0o700)
    subprocess.run(["caddy", "reload", "--config", str(root / "Caddyfile"), "--adapter", "caddyfile",
                    "--address", admin_address, "--force"], cwd=root,
                   env=dict(env, CREDENTIALS_DIRECTORY=str(reload_credentials)), stdout=log, stderr=log, check=True)
    for headers in [{}, {"Remote-User": "hieronim", "X-Copyparty-User": "admin", proof: "1"},
                    {"Cookie": "fixture-auth=invalid"}]:
        assert request("/nas/shared/?ls", headers)[0] == 401
    for user in ["admin", "unknown"]:
        assert request("/nas/shared/?ls", {"Cookie": "fixture-auth=" + user})[0] == 403
    for user in ["hieronim", "sarcia"]:
        cookie = {"Cookie": "fixture-auth=" + user + "; cppwd=" + native_sessions["admin"],
                  "Remote-User": "admin", "X-Copyparty-User": "admin", proof: "1"}
        status, headers, body = request("/nas/shared/?ls", cookie)
        assert status == 200 and json.loads(body)["acct"] == user
        assert "Set-Cookie" not in headers, "Never hand a reusable native SID to an SSO-only browser"
        assert proof.encode() not in body
        assert request(f"/nas/{user}/original.txt", cookie)[0] == 200
        other = "sarcia" if user == "hieronim" else "hieronim"
        assert request(f"/nas/{other}/original.txt", cookie)[0] in [403, 404]
    # Browser writes use the authenticated header, not an anonymous method-only exception.
    cookie = {"Cookie": "fixture-auth=hieronim"}
    assert request("/nas/shared/browser.txt", cookie, "PUT", b"browser payload")[0] in [200, 201, 204]
    assert request("/nas/shared/browser.txt", cookie)[2] == b"browser payload"
    assert request("/nas/shared/browser.txt", cookie, "DELETE")[0] in [200, 204]
    for user in ["admin", "hieronim", "sarcia"]:
        before = calls["auth"]
        result = request("/nas/shared/?ls", basic(user))
        assert result[0] == 200 and json.loads(result[2])["acct"] == user
        assert calls["auth"] == before
    # Native password-only behavior is unchanged, not an added legacy-name alias.
    result = request("/nas/shared/?ls", basic("sarka", passwords["sarcia"]))
    assert result[0] == 200 and json.loads(result[2])["acct"] == "sarcia"
    assert request("/nas/sarka/original.txt", basic("sarcia"))[0] in [403, 404]
    assert request("/nas/hieronim/original.txt", basic("sarcia"))[0] in [403, 404]
    before = calls["auth"]
    assert request("/nas/shared/", {**basic("sarcia"), "Depth": "1"}, "PROPFIND")[0] == 207
    assert request("/nas/shared/", {"Depth": "1"}, method="PROPFIND")[0] in [401, 403]
    assert calls["auth"] == before
    bad = basic("unknown", "wrong-synthetic-password")
    bad.update({"X-Copyparty-User": "admin", proof: "1"})
    assert request("/nas/hieronim/original.txt", bad)[0] in [401, 403, 404]
    assert calls["auth"] == before
    native = basic("sarcia")
    assert request("/nas/shared/client.txt", native, "PUT", b"native client payload")[0] in [200, 201, 204]
    assert request("/nas/shared/client.txt", native)[2] == b"native client payload"
    assert request("/nas/shared/client.txt", native, "DELETE")[0] in [200, 204]

    assert (nas / "sarcia/original.txt").read_text() == "Original synthetic sarcia data"
    assert proof.encode() not in (root / "copyparty.log").read_bytes().lower()
    assert proof.encode() not in (root / "caddy.log").read_bytes().lower()
    print("PASS runtime-secret setup and reload, SSO spoof/unknown/cross-user denial, native passwords/WebDAV/writes")
finally:
    for child in reversed(children):
        if child.poll() is None:
            stop(child)
    auth.shutdown()
