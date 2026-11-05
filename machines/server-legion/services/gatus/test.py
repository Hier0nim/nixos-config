"""Check notification permissions, incident alerts and shared-status privacy."""

import contextlib
import http.server
import importlib.util
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.request

import yaml


def port():
    """Find an available loopback port for a test process."""
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def request(url, token=None, data=None, headers=None):
    """Return the HTTP status and body for a native test endpoint."""
    headers = dict(headers or {})
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(url, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=3) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()


def until(check, timeout=40):
    """Wait for observable application behavior, not a fixed startup sleep."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            result = check()
            if result:
                return result
        except (OSError, ValueError):
            pass
        time.sleep(0.2)
    raise AssertionError("Timed out waiting for native application behavior")


class Probe(http.server.BaseHTTPRequestHandler):
    """Controllable app-health endpoint, independent of the notification servers."""

    healthy = True

    def do_GET(self):
        self.send_response(200 if self.healthy else 503)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"status": "UP" if self.healthy else "DOWN",
                                    "path": self.path, "headers": dict(self.headers)}).encode())

    def log_message(self, *_):
        pass


with tempfile.TemporaryDirectory() as directory, contextlib.ExitStack() as stack:
    root = Path(directory)
    settings = json.loads(Path(os.environ["FIXTURES"]).read_text())
    spec = importlib.util.spec_from_file_location("ntfy_secrets", os.environ["NTFY_GENERATOR"])
    generator = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(generator)
    credentials = root / "credentials"
    credentials.mkdir(mode=0o700)
    generator.generate(credentials)
    env = os.environ | dict(line.split("=", 1) for line in (credentials / "server.env").read_text().splitlines())
    reader = (credentials / "hieronim-token").read_text()
    publisher = (credentials / "gatus-token").read_text()
    assert reader != publisher
    assert all(p.stat().st_mode & 0o777 == 0o400 for p in credentials.iterdir())
    ntfy_url, gatus_url = (f"http://127.0.0.1:{port()}" for _ in range(2))
    probe = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Probe)
    stack.callback(probe.server_close)
    stack.callback(probe.shutdown)
    threading.Thread(target=probe.serve_forever, daemon=True).start()
    ntfy = settings["ntfy"] | {
        "base-url": ntfy_url, "listen-http": ntfy_url.removeprefix("http://"),
        "auth-file": str(root / "auth.db"), "cache-file": str(root / "cache.db"),
        "visitor-request-limit-burst": 1000, "visitor-request-limit-replenish": "1s",
    }
    gatus = settings["gatus"]
    gatus["web"]["port"] = int(gatus_url.rsplit(":", 1)[1])
    gatus["storage"]["path"] = str(root / "gatus.db")
    gatus["alerting"]["ntfy"] |= {"url": ntfy_url, "token": publisher}
    alert = gatus["endpoints"][0]["alerts"]
    gatus["endpoints"] = [{"name": "Probe", "group": "Test", "url": f"http://127.0.0.1:{probe.server_port}/",
                            "interval": "1s", "conditions": ["[STATUS] == 200", "[BODY].status == UP"], "alerts": alert, "ui": gatus["endpoints"][0]["ui"]}]
    backup = gatus["external-endpoints"][0]
    backup["token"] = "test-backup-bearer"
    # Keep the real 26-hour deadline during incident tests, then test expiry separately.
    for name, value in (("ntfy", ntfy), ("gatus", gatus)):
        (root / f"{name}.yaml").write_text(yaml.safe_dump(value))

    def launch(name):
        log = stack.enter_context((root / f"{name}.log").open("ab"))
        command = {"ntfy": ["ntfy", "serve", "-c", str(root / "ntfy.yaml")],
                   "gatus": ["gatus"],
                   "caddy": ["caddy", "run", "--config", str(root / "Caddyfile"), "--adapter", "caddyfile"]}[name]
        process = subprocess.Popen(command, env=env | {"GATUS_CONFIG_PATH": str(root / "gatus.yaml")}, stdout=log, stderr=log)
        stack.callback(lambda: process.poll() is None and (process.send_signal(signal.SIGTERM), process.wait(timeout=10)))
        return process

    ntfy_process = launch("ntfy")
    until(lambda: request(ntfy_url + "/v1/health")[0] == 200)
    assert request(ntfy_url + "/infra/json?poll=1")[0] in (401, 403)
    assert request(ntfy_url + "/infra/json?poll=1", publisher)[0] == 403
    assert request(ntfy_url + "/infra", reader, b"not permitted")[0] == 403
    assert request(ntfy_url + "/other", publisher, b"not permitted")[0] == 403
    assert request(ntfy_url + "/infra", publisher, b"publisher positive control")[0] == 200

    def messages():
        status, body = request(ntfy_url + "/infra/json?poll=1", reader)
        assert status == 200
        return [json.loads(line) for line in body.splitlines() if line]

    def alerts_for(name):
        return [m for m in messages() if name in m.get("title", "")]

    gatus_process = launch("gatus")
    until(lambda: request(gatus_url + "/api/v1/endpoints/statuses")[0] == 200)
    until(lambda: any(ep["key"] == "test_probe" and ep["results"] and ep["results"][0]["success"]
                      for ep in json.loads(request(gatus_url + "/api/v1/endpoints/statuses")[1])))
    Probe.healthy = False
    until(lambda: len(alerts_for("Probe")) == 1)
    time.sleep(4)
    assert len(alerts_for("Probe")) == 1, "Duplicate failure notification"
    Probe.healthy = True
    until(lambda: len(alerts_for("Probe")) == 2)
    assert "resolved" in alerts_for("Probe")[-1]["message"]
    summary_url = f"http://127.0.0.1:{port()}"
    summary_config = settings["summary"].replace("http://127.0.0.1:8083", gatus_url)
    summary_config = summary_config.replace("127.0.0.1:8083", gatus_url.removeprefix("http://"))
    for backend_port in (3101, 3923):
        summary_config = summary_config.replace(f"127.0.0.1:{backend_port}", f"127.0.0.1:{probe.server_port}")
    (root / "Caddyfile").write_text("{\nadmin off\n}\n" + summary_url + " {\n" + summary_config + "\n}\n")
    launch("caddy")
    summary_endpoint = summary_url + "/gatus-status/api/v1/endpoints/statuses"
    until(lambda: request(summary_endpoint)[0] == 200)
    for endpoint in json.loads(request(summary_endpoint + "?pageSize=1000&page=2")[1]):
        assert len(endpoint["results"]) <= 1 and not endpoint.get("events"), "Shared summary exposed history"
        for result in endpoint["results"]:
            assert set(result) <= {"success", "status", "duration", "timestamp"}, "Shared summary exposed diagnostic fields"
    assert request(summary_url + "/gatus-status/api/v1/endpoints/test_probe")[0] == 404
    assert request(summary_endpoint, data=b"")[0] == 405
    identity_headers = {name: "test-only" for name in (
        "Authorization", "Cookie", "Proxy-Authorization", "Remote-User", "X-Forwarded-User", "X-Copyparty-User")}
    for route, path in (("actual", "/health"), ("copyparty", "/")):
        status, body = request(f"{summary_url}/{route}?pw=test-only", headers=identity_headers)
        if status == 404:
            continue
        result = json.loads(body)
        assert status == 200 and result["path"].rstrip("?") == path, "Health bridge forwarded query credentials"
        assert not set(identity_headers) & set(result["headers"]), "Health bridge forwarded identity headers"
    backup_url = gatus_url + "/api/v1/endpoints/backups_storage-box/external?success=true"
    assert request(backup_url, "wrong", b"")[0] in (401, 403)
    assert request(backup_url, "test-backup-bearer", b"")[0] == 200
    failure_url = backup_url.replace("success=true", "success=false")
    assert request(failure_url, "test-backup-bearer", b"")[0] == 200
    until(lambda: len(alerts_for("Storage Box")) == 1)
    assert request(backup_url, "test-backup-bearer", b"")[0] == 200
    until(lambda: len(alerts_for("Storage Box")) == 2)

    for process in (gatus_process, ntfy_process):
        process.send_signal(signal.SIGTERM)
        process.wait(timeout=10)
    ntfy_process = launch("ntfy")
    until(lambda: request(ntfy_url + "/v1/health")[0] == 200)
    assert len(alerts_for("Probe")) == 2, "Cached messages or native auth lost after restart"
    backup["heartbeat"]["interval"] = "10s"
    (root / "gatus.yaml").write_text(yaml.safe_dump(gatus))
    gatus_process = launch("gatus")
    until(lambda: request(gatus_url + "/health")[0] == 200)
    assert request(backup_url, "test-backup-bearer", b"")[0] == 200
    until(lambda: len(alerts_for("Storage Box")) == 3, timeout=65)
    assert request(backup_url, "test-backup-bearer", b"")[0] == 200
    until(lambda: len(alerts_for("Storage Box")) == 4)
    print("PASS: native topic ACLs, single failure/recovery alerts, authenticated backup heartbeat, restart persistence and summary privacy")
