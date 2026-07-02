#!@python@
import datetime
import fcntl
import html
import os
import subprocess
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TORRENT_DIR = os.environ["AUDIOBOOK_TORRENT_DIR"]
REVIEW_DIR = os.environ["AUDIOBOOK_REVIEW_DIR"]
LIBRARY_DIR = os.environ["AUDIOBOOK_LIBRARY_DIR"]
STATE_DIR = os.environ["AUDIOBOOK_IMPORT_STATE_DIR"]
IMPORT_CMD = os.environ["AUDIOBOOK_IMPORT_CMD"]
REVIEW_CMD = os.environ["AUDIOBOOK_REVIEW_CMD"]
HOST = os.environ.get("AUDIOBOOK_IMPORT_DASHBOARD_HOST", "127.0.0.1")
PORT = int(os.environ.get("AUDIOBOOK_IMPORT_DASHBOARD_PORT", "8010"))
AUDIO_EXTS = {".m4b", ".m4a", ".mp3", ".flac", ".ogg", ".opus", ".aac"}

def esc(value):
    return html.escape(str(value), quote=True)

def human_size(size):
    value = float(size)
    for unit in ["B", "KiB", "MiB", "GiB", "TiB"]:
        if value < 1024 or unit == "TiB":
            return f"{value:.1f} {unit}" if unit != "B" else f"{int(value)} B"
        value /= 1024
    return f"{value:.1f} TiB"

def safe_child(root, name):
    if not name or name in {".", ".."} or "/" in name or "\x00" in name:
        raise ValueError("invalid directory name")
    root_real = os.path.realpath(root)
    path = os.path.realpath(os.path.join(root_real, name))
    if os.path.dirname(path) != root_real:
        raise ValueError("path escapes root directory")
    if not os.path.isdir(path):
        raise ValueError("directory no longer exists")
    return path

def safe_destination(value):
    value = value.strip()
    if not value:
        return ""
    parts = value.split("/")
    if value.startswith("/") or any(part in {"", ".", ".."} for part in parts):
        raise ValueError("destination must be a safe relative path")
    return value

def scan_dir(root):
    rows = []
    if not os.path.isdir(root):
        return rows
    for name in sorted(os.listdir(root), key=str.lower):
        try:
            path = safe_child(root, name)
        except Exception:
            continue
        total = 0
        audio_count = 0
        newest = 0
        for dirpath, dirnames, filenames in os.walk(path):
            dirnames[:] = [d for d in dirnames if not os.path.islink(os.path.join(dirpath, d))]
            for filename in filenames:
                file_path = os.path.join(dirpath, filename)
                try:
                    st = os.lstat(file_path)
                except OSError:
                    continue
                if os.path.islink(file_path):
                    continue
                total += st.st_size
                newest = max(newest, int(st.st_mtime))
                if os.path.splitext(filename)[1].lower() in AUDIO_EXTS:
                    audio_count += 1
        rows.append({"name": name, "size": human_size(total), "audio_count": audio_count, "updated": newest})
    return rows

def scan_pending():
    return scan_dir(REVIEW_DIR)

def scan_torrents():
    return scan_dir(TORRENT_DIR)

def read_log(name, limit=15):
    path = os.path.join(STATE_DIR, name)
    if not os.path.exists(path):
        return []
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            lines = handle.readlines()[-limit:]
    except OSError as exc:
        return [f"Could not read {name}: {exc}"]
    return [line.rstrip("\n") for line in reversed(lines)]

def run_command(args):
    os.makedirs(STATE_DIR, exist_ok=True)
    lock_path = os.path.join(STATE_DIR, "dashboard.lock")
    with open(lock_path, "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 409, "Another dashboard action is already running."
        completed = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=None)
        return completed.returncode, completed.stdout

def render_page(message=None, code=200):
    pending = scan_pending()
    torrents = scan_torrents()
    imported = read_log("imports.log")
    reviewed = read_log("reviews.log")
    now = datetime.datetime.now().astimezone().isoformat(timespec="seconds")
    msg_html = ""
    if message is not None:
        cls = "ok" if code == 0 else "err"
        msg_html = f"<section class='{cls}'><h2>Last action</h2><pre>{esc(message)}</pre></section>"
    torrent_rows = []
    for item in torrents:
        updated = datetime.datetime.fromtimestamp(item["updated"]).strftime("%Y-%m-%d %H:%M") if item["updated"] else "unknown"
        torrent_rows.append(f"""
          <tr>
            <td><strong>{esc(item["name"])}</strong><br><small>{esc(item["audio_count"])} audio file(s), {esc(item["size"])}, updated {esc(updated)}</small></td>
            <td>
              <form method="post" action="/review">
                <input type="hidden" name="name" value="{esc(item["name"])}">
                <label>Review name <input name="destination" placeholder="Blank keeps torrent folder name"></label>
                <button name="mode" value="dry-run">Dry run copy</button>
                <button name="mode" value="import">Copy to review</button>
              </form>
            </td>
          </tr>
        """)
    torrents_html = "\n".join(torrent_rows) if torrent_rows else "<tr><td colspan='2'>No completed audiobook torrent folders found.</td></tr>"
    rows = []
    for item in pending:
        updated = datetime.datetime.fromtimestamp(item["updated"]).strftime("%Y-%m-%d %H:%M") if item["updated"] else "unknown"
        rows.append(f"""
          <tr>
            <td><strong>{esc(item["name"])}</strong><br><small>{esc(item["audio_count"])} audio file(s), {esc(item["size"])}, updated {esc(updated)}</small></td>
            <td>
              <form method="post" action="/import">
                <input type="hidden" name="name" value="{esc(item["name"])}">
                <label>Destination <input name="destination" placeholder="Author/Title or blank for auto/folder"></label>
                <label><input type="checkbox" name="auto" checked> auto tags</label>
                <button name="mode" value="dry-run">Dry run</button>
                <button name="mode" value="import">Import</button>
              </form>
            </td>
          </tr>
        """)
    pending_html = "\n".join(rows) if rows else "<tr><td colspan='2'>No pending review folders.</td></tr>"
    def log_block(title, lines):
        body = "\n".join(esc(line) for line in lines) if lines else "No entries yet."
        return f"<section><h2>{esc(title)}</h2><pre>{body}</pre></section>"
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Audiobook imports</title>
<style>
  body {{ font-family: system-ui, sans-serif; margin: 2rem; line-height: 1.45; background: #111827; color: #e5e7eb; }}
  a {{ color: #93c5fd; }} table {{ width: 100%; border-collapse: collapse; background: #1f2937; }}
  th, td {{ border-bottom: 1px solid #374151; padding: .75rem; text-align: left; vertical-align: top; }}
  input[type=text], input:not([type]) {{ width: min(28rem, 95%); padding: .35rem; }}
  button {{ margin-left: .35rem; padding: .4rem .7rem; }} pre {{ white-space: pre-wrap; background: #030712; padding: 1rem; overflow: auto; }}
  .ok {{ border-left: 4px solid #22c55e; padding-left: 1rem; }} .err {{ border-left: 4px solid #ef4444; padding-left: 1rem; }}
  small {{ color: #9ca3af; }} form {{ display: flex; flex-wrap: wrap; gap: .5rem; align-items: center; }}
</style></head><body>
<h1>Audiobook imports</h1>
<p>Torrent downloads: <code>{esc(TORRENT_DIR)}</code><br>Review staging: <code>{esc(REVIEW_DIR)}</code><br>Library: <code>{esc(LIBRARY_DIR)}</code><br>Updated: {esc(now)}</p>
{msg_html}
<section><h2>Torrent downloads</h2>
<p>Copy completed qBittorrent audiobook folders into review staging while leaving the original torrent data in place for seeding.</p>
<table><thead><tr><th>Folder</th><th>Action</th></tr></thead><tbody>{torrents_html}</tbody></table></section>
<section><h2>Pending review folders</h2>
<form method="post" action="/import-all" style="margin-bottom: 1rem">
  <label><input type="checkbox" name="auto" checked> auto tags</label>
  <button name="mode" value="dry-run">Dry-run all</button>
  <button name="mode" value="import">Import all</button>
</form>
<table><thead><tr><th>Folder</th><th>Action</th></tr></thead><tbody>{pending_html}</tbody></table></section>
{log_block("Recent imports", imported)}
{log_block("Recent review copies", reviewed)}
</body></html>"""

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in {"/", ""}:
            self.send_error(404)
            return
        self.respond(render_page())

    def same_origin_ok(self):
        header = self.headers.get("Origin") or self.headers.get("Referer")
        if not header:
            return True
        parsed = urllib.parse.urlparse(header)
        return parsed.netloc == self.headers.get("Host")


    def do_POST(self):
        if not self.same_origin_ok():
            self.respond(render_page("Refusing cross-origin form submission.", 1), status=403)
            return
        length = int(self.headers.get("Content-Length", "0"))
        if length > 65536:
            self.respond(render_page("Request body too large.", 1), status=413)
            return
        data = urllib.parse.parse_qs(self.rfile.read(length).decode("utf-8", errors="replace"))
        mode = data.get("mode", ["dry-run"])[0]
        dry_run = mode != "import"
        try:
            if self.path == "/import":
                name = data.get("name", [""])[0]
                source = safe_child(REVIEW_DIR, name)
                destination = safe_destination(data.get("destination", [""])[0])
                args = [IMPORT_CMD]
                if dry_run:
                    args.append("--dry-run")
                if "auto" in data and not destination:
                    args.append("--auto")
                args.append(source)
                if destination:
                    args.append(destination)
            elif self.path == "/review":
                name = data.get("name", [""])[0]
                source = safe_child(TORRENT_DIR, name)
                destination = safe_destination(data.get("destination", [""])[0])
                args = [REVIEW_CMD]
                if dry_run:
                    args.append("--dry-run")
                args.append(source)
                if destination:
                    args.append(destination)
            elif self.path == "/import-all":
                args = [IMPORT_CMD, "--all"]
                if dry_run:
                    args.append("--dry-run")
                if "auto" in data:
                    args.append("--auto")
            else:
                self.send_error(404)
                return
            code, output = run_command(args)
            self.respond(render_page(output, code))
        except Exception as exc:
            self.respond(render_page(str(exc), 1), status=400)

    def respond(self, body, status=200):
        raw = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)

    def log_message(self, format, *args):
        print(f"{self.address_string()} - {format % args}")

if __name__ == "__main__":
    os.makedirs(STATE_DIR, exist_ok=True)
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Audiobook import dashboard listening on http://{HOST}:{PORT}")
    server.serve_forever()
