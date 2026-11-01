"""Exercise generated Caddy gates, API routing and structured error-log filtering."""

import http.client
import http.server
import json
import os
from pathlib import Path
import socket
import subprocess
import threading
import time
from urllib.parse import unquote, urlsplit

routes = json.loads(Path(os.environ["INGRESS_ROUTES"]).read_text())
assert routes, "No browser gates to test"
calls = {"auth": 0, "backend": 0}


class Fixture(http.server.BaseHTTPRequestHandler):
    """Supply synthetic browser admission and native backend challenges."""

    def log_message(self, *args):
        """Suppress access logs."""

    def respond(self, status, body=b"", headers=None):
        """Write a complete synthetic response."""
        self.send_response(status)
        for name, value in (headers or {}).items():
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        """Check admission or native credentials, then echo forwarding details."""
        if self.server.kind == "auth":
            calls["auth"] += 1
            assert self.headers.get("Authorization") is None
            assert self.headers.get("Proxy-Authorization") is None
            valid = "fixture-auth=valid" in self.headers.get("Cookie", "")
            self.respond(200 if valid else 401)
            return
        calls["backend"] += 1
        path = unquote(urlsplit(self.path).path)
        assert not path.startswith("/qbittorrent")
        if self.headers.get("Host", "").startswith("pobieralnia.") and path.startswith("/api/"):
            if "fixture-native=valid" not in self.headers.get("Cookie", ""):
                self.respond(403)
                return
        elif path == "/api" or path.startswith("/api/"):
            if self.headers.get("X-Api-Key") != "fixture-key":
                self.respond(401)
                return
        length = int(self.headers.get("Content-Length", 0))
        result = {
            "method": self.command,
            "path": self.path,
            "body": self.rfile.read(length).decode(),
            "authorization": self.headers.get("Authorization"),
        }
        self.respond(200, json.dumps(result).encode())

    do_POST = do_GET
    do_OPTIONS = do_GET


servers = []
for kind in ("auth", "backend"):
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Fixture)
    server.kind = kind
    threading.Thread(target=server.serve_forever, daemon=True).start()
    servers.append(server)
auth_port, backend_port = [server.server_port for server in servers]
with socket.socket() as reservation:
    reservation.bind(("127.0.0.1", 0))
    port = reservation.getsockname()[1]
# Keep this port bound but not listening so the failed upstream is deterministic.
failed_upstream = socket.socket()
failed_upstream.bind(("127.0.0.1", 0))
failed_port = failed_upstream.getsockname()[1]
text = "{\n admin off\n auto_https off\n log {\n" + os.environ["CADDY_LOG_FORMAT"] + "\n}\n}\n"
for name, service in routes.items():
    route = service["route"].replace("127.0.0.1:9091", f"127.0.0.1:{auth_port}")
    route = route.replace(service["upstream"], f"http://127.0.0.1:{backend_port}")
    assert "basic_auth" not in route
    assert "api*" not in route
    text += f"http://{name}.test:{port} {{\n{route}\n}}\n"
text += f"http://errors.test:{port} {{\n reverse_proxy 127.0.0.1:{failed_port}\n}}\n"
Path("Caddyfile").write_text(text)


def request(name, path, headers=None, method="GET", body=None):
    """Call a local synthetic route without exposing credentials in output."""
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
    connection.request(method, path, body=body, headers={"Host": f"{name}.test", **(headers or {})})
    response = connection.getresponse()
    data = response.read()
    assert response.getheader("WWW-Authenticate") is None
    connection.close()
    return response.status, data


with Path("caddy.log").open("wb") as log:
    caddy = subprocess.Popen(
        ["caddy", "run", "--config", "Caddyfile", "--adapter", "caddyfile"],
        stdout=log,
        stderr=log,
    )
    try:
        for attempt in range(100):
            if caddy.poll() is not None:
                raise RuntimeError("Synthetic Caddy exited; inspect its private fixture log")
            try:
                request(next(iter(routes)), "/")
                break
            except OSError:
                time.sleep(0.05)
        else:
            raise RuntimeError("Caddy did not start")
        for name, service in routes.items():
            prefix = service["pathPrefix"] or ""
            ui = prefix + "/"
            for headers in (
                {},
                {"Authorization": "Basic Zml4dHVyZTpmaXh0dXJl"},
                {"Remote-User": "hieronim", "Remote-Groups": "media-admin"},
                {"Cookie": "fixture-auth=invalid"},
            ):
                before = calls["backend"]
                assert request(name, ui, headers)[0] == 401, name
                assert calls["backend"] == before, name
            before = calls["backend"]
            assert request(name, prefix + "/apiculture")[0] == 401, name
            assert calls["backend"] == before, name
            status, data = request(
                name,
                ui + "?fixture=1",
                {"Cookie": "fixture-auth=valid", "Authorization": "Bearer fixture-token"},
                method="POST",
                body="fixture-body",
            )
            assert status == 200, name
            result = json.loads(data)
            assert result["path"] == "/?fixture=1", name
            assert result["body"] == "fixture-body" and result["method"] == "POST"
            expected_auth = None if name == "pobieralnia" else "Bearer fixture-token"
            assert result["authorization"] == expected_auth
            api = prefix + "/api/v3/status"
            for headers in ({}, {"X-Api-Key": "invalid"}):
                assert request(name, api, headers)[0] in (401, 403), name
            before = calls["auth"]
            status, _ = request(name, api, {"X-Api-Key": "fixture-key", "Cookie": "fixture-native=valid"})
            assert status == (200 if service["integrationApiBypass"] else 401), name
            assert (calls["auth"] == before) == service["integrationApiBypass"], name
        assert request(
            "errors",
            "/synthetic-path-secret?api_key=synthetic-query-secret",
            {"X-Fixture-Secret": "synthetic-header-secret"},
        )[0] == 502
    finally:
        caddy.terminate()
        caddy.wait(timeout=10)
        failed_upstream.close()
        for server in servers:
            server.shutdown()
            server.server_close()

log_text = Path("caddy.log").read_text()
for secret in ("synthetic-path-secret", "synthetic-query-secret", "synthetic-header-secret"):
    assert secret not in log_text, "Sensitive request data reached the structured error log"
entries = [json.loads(line) for line in log_text.splitlines() if line.startswith("{")]
error = next(entry for entry in entries if entry.get("status") == 502)
assert "uri" not in error["request"] and "headers" not in error["request"]
assert error["request"]["method"] == "GET"
print("Browser gates, exact API paths, forwarding and structured error-log filtering passed")
