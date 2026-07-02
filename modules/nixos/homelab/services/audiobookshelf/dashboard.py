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
        rows.append({"name": name, "path": path, "size": human_size(total), "audio_count": audio_count, "updated": newest})
    return rows


def scan_pending():
    return scan_dir(REVIEW_DIR)


def scan_torrents():
    return scan_dir(TORRENT_DIR)


def read_log(name, limit=15):
    lines = _read_log_lines(name)
    if limit is not None:
        lines = lines[-limit:]
    return [line.rstrip("\n") for line in reversed(lines)]


def _read_log_lines(name):
    path = os.path.join(STATE_DIR, name)
    if not os.path.exists(path):
        return []
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            return handle.readlines()
    except OSError as exc:
        return [f"Could not read {name}: {exc}\n"]


def _parse_events(name):
    events = []
    for line in _read_log_lines(name):
        parts = line.rstrip("\n").split("\t")
        if len(parts) >= 3:
            events.append({"time": parts[0], "source": os.path.realpath(parts[1]), "dest": os.path.realpath(parts[2])})
    return events


def _latest_event_by_source(events, source):
    source_real = os.path.realpath(source)
    for event in reversed(events):
        if event["source"] == source_real:
            return event
    return None


def _folder_name(path):
    return os.path.basename(path)


def _find_library_match(dest):
    """Try to find the dest path in the library, handling renames/reorganization.
    Returns the actual library path if found, None otherwise.
    """
    target_name = _folder_name(dest)
    # Extract author from dest path relative to LIBRARY_DIR
    try:
        rel = os.path.relpath(dest, LIBRARY_DIR)
        parts = rel.split(os.sep)
        author = parts[0] if len(parts) > 1 else None
    except (ValueError, IndexError):
        author = None

    # First try exact basename match across all authors
    for auth in os.listdir(LIBRARY_DIR):
        auth_dir = os.path.join(LIBRARY_DIR, auth)
        if not os.path.isdir(auth_dir):
            continue
        for title in os.listdir(auth_dir):
            if title == target_name and os.path.isdir(os.path.join(auth_dir, title)):
                return os.path.join(auth_dir, title)

    # Then try substring match within the same author (handles renames like
    # 'City Watch 01 - Guards! Guards!' -> 'Guards! Guards!')
    if author:
        auth_dir = os.path.join(LIBRARY_DIR, author)
        if os.path.isdir(auth_dir):
            for title in os.listdir(auth_dir):
                title_path = os.path.join(auth_dir, title)
                if not os.path.isdir(title_path):
                    continue
                if title in target_name or target_name in title:
                    return title_path

    return None


def _determine_torrent_status(item, review_events, import_events):
    review_event = _latest_event_by_source(review_events, item["path"])
    if review_event is None:
        return {"code": "new", "label": "New", "summary": "Ready to prepare for review."}
    import_event = _latest_event_by_source(import_events, review_event["dest"])
    if import_event is not None:
        if os.path.exists(import_event["dest"]):
            return {"code": "imported", "label": "Already in library", "summary": "This download was already prepared and added to the library."}
        if _find_library_match(import_event["dest"]) is not None:
            return {"code": "imported", "label": "Already in library", "summary": "This download was already added to the library (library path was renamed or reorganized)."}
        if not os.path.exists(review_event["dest"]):
            return {"code": "imported", "label": "Already handled", "summary": "This download was prepared and imported before, and the original review folder is gone."}
        return {"code": "attention", "label": "Needs attention", "summary": "It was imported before, but the library folder is missing."}
    if os.path.exists(review_event["dest"]):
        return {"code": "in_review", "label": "Already in review", "summary": "This download is already waiting in the review area."}
    return {"code": "attention", "label": "Needs attention", "summary": "It was prepared before, but the review copy is missing."}


def _determine_review_status(item, import_events):
    import_event = _latest_event_by_source(import_events, item["path"])
    if import_event is None:
        return {"code": "new", "label": "Ready", "summary": "Ready to add to the library."}
    if os.path.exists(import_event["dest"]):
        return {"code": "imported", "label": "Already in library", "summary": "This review folder was already added to the library."}
    if _find_library_match(import_event["dest"]) is not None:
        return {"code": "imported", "label": "Already in library", "summary": "This review folder was already added to the library (library path was renamed or reorganized)."}
    return {"code": "attention", "label": "Needs attention", "summary": "It was imported before, but the library folder is missing."}




def _friendly_summary(raw_output, exit_code):
    text = raw_output.strip()
    if exit_code == 0:
        if "Dry run" in text or "dry run" in text:
            return "Preview complete. Nothing was changed."
        if "Copied for review" in text:
            return "Prepared for review."
        if "Imported" in text or "imports complete" in text:
            return "Import complete."
        return "Done."
    if "already exists" in text:
        return "That destination already exists. Choose a different name."
    if text:
        return text.split("\n")[0][:200]
    return "Action failed."


def _format_item_row(item, form_action, button_label, extra_fields=None):
    updated = datetime.datetime.fromtimestamp(item["updated"]).strftime("%Y-%m-%d %H:%M") if item["updated"] else "unknown"
    fields_html = ""
    if extra_fields:
        for key, value in extra_fields.items():
            fields_html += f'\n                <input type="hidden" name="{esc(key)}" value="{esc(value)}">'
    return f"""
          <tr>
            <td><strong>{esc(item["name"])}</strong><br><small>{esc(item["audio_count"])} audio file(s), {esc(item["size"])}, updated {esc(updated)}</small></td>
            <td>
              <form method="post" action="{esc(form_action)}">
                <input type="hidden" name="name" value="{esc(item["name"])}">
                {fields_html}
                <label>Destination <input name="destination" placeholder="Author/Title or blank for auto/folder"></label>
                <label><input type="checkbox" name="auto" checked> auto tags</label>
                <button name="mode" value="dry-run">Dry run</button>
                <button name="mode" value="import">{esc(button_label)}</button>
              </form>
            </td>
          </tr>
        """


def _status_row(item, status):
    updated = datetime.datetime.fromtimestamp(item["updated"]).strftime("%Y-%m-%d %H:%M") if item["updated"] else "unknown"
    css = "badge-attention" if status["code"] == "attention" else "badge-done"
    return f"""
          <tr>
            <td><strong>{esc(item["name"])}</strong> <span class="{css}">{esc(status["label"])}</span><br><small>{esc(item["audio_count"])} audio file(s), {esc(item["size"])}, updated {esc(updated)}</small></td>
            <td><small>{esc(status["summary"])}</small></td>
          </tr>
        """


def _torrent_row(item):
    updated = datetime.datetime.fromtimestamp(item["updated"]).strftime("%Y-%m-%d %H:%M") if item["updated"] else "unknown"
    return f"""
          <tr>
            <td><strong>{esc(item["name"])}</strong><br><small>{esc(item["audio_count"])} audio file(s), {esc(item["size"])}, updated {esc(updated)}</small></td>
            <td>
              <form method="post" action="/review">
                <input type="hidden" name="name" value="{esc(item["name"])}">
                <label>Review name <input name="destination" placeholder="Blank keeps the current name"></label>
                <button name="mode" value="dry-run">Preview</button>
                <button name="mode" value="import">Prepare for review</button>
              </form>
            </td>
          </tr>
        """


def _log_block(title, lines):
    body = "\n".join(esc(line) for line in lines) if lines else "No entries yet."
    return f"<details><summary>{esc(title)}</summary><pre>{body}</pre></details>"


def _build_view_model(show_handled=False):
    torrents = scan_torrents()
    pending = scan_pending()
    reviewed_log = read_log("reviews.log")
    imported_log = read_log("imports.log")
    review_events = _parse_events("reviews.log")
    import_events = _parse_events("imports.log")

    new_torrents = []
    handled_torrents = []
    attention_items = []
    for item in torrents:
        status = _determine_torrent_status(item, review_events, import_events)
        if status["code"] == "new":
            new_torrents.append(item)
        elif status["code"] == "attention":
            attention_items.append((item, status))
        else:
            handled_torrents.append((item, status))

    pending_review = []
    handled_review = []
    for item in pending:
        status = _determine_review_status(item, import_events)
        if status["code"] == "new":
            pending_review.append(item)
        elif status["code"] == "attention":
            attention_items.append((item, status))
        else:
            handled_review.append((item, status))

    return {
        "torrents": torrents,
        "pending": pending,
        "reviewed_log": reviewed_log,
        "imported_log": imported_log,
        "new_torrents": new_torrents,
        "handled_torrents": handled_torrents,
        "pending_review": pending_review,
        "handled_review": handled_review,
        "attention_items": attention_items,
        "show_handled": show_handled,
    }


def _render_torrents_section(new_torrents, handled_torrents, show_handled):
    rows = [_torrent_row(item) for item in new_torrents]
    if show_handled:
        for item, status in handled_torrents:
            rows.append(_status_row(item, status))
    total_handled = len(handled_torrents)
    toggle = ""
    if total_handled > 0:
        if show_handled:
            toggle = f'<p id="toggle-handled"><a href="/">Hide already handled ({total_handled})</a></p>'
        else:
            toggle = f'<p id="toggle-handled"><a href="/?show=handled">Show already handled ({total_handled})</a></p>'
    body = "\n".join(rows) if rows else "<tr><td colspan='2'>No new audiobook downloads found.</td></tr>"
    return f"<section class='card'><h2>New downloads</h2><p>Prepare completed audiobook downloads for review. The original downloads stay in place.</p>{toggle}<table><thead><tr><th>Folder</th><th>Action</th></tr></thead><tbody>{body}</tbody></table></section>"


def _render_pending_section(pending_review, handled_review, show_handled):
    rows = [_format_item_row(item, "/import", "Import") for item in pending_review]
    if show_handled:
        for item, status in handled_review:
            rows.append(_status_row(item, status))
    body = "\n".join(rows) if rows else "<tr><td colspan='2'>No review folders ready to add.</td></tr>"
    return f"""
<section class="card"><h2>Ready to add to library</h2>
<p>These folders are ready to become Audiobookshelf library entries.</p>
<form method="post" action="/import-all" class="bulk-actions">
  <label><input type="checkbox" name="auto" checked> Use embedded audiobook metadata when possible</label>
  <button name="mode" value="dry-run">Preview all</button>
  <button name="mode" value="import">Import all</button>
</form>
<table><thead><tr><th>Folder</th><th>Action</th></tr></thead><tbody>{body}</tbody></table></section>
    """


def _render_attention_section(attention_items):
    if not attention_items:
        return ""
    rows = "\n".join(_status_row(item, status) for item, status in attention_items)
    return f"<section class='card warn'><h2>Needs attention</h2><p>These items have a previous action recorded, but something no longer matches on disk.</p><table><thead><tr><th>Folder</th><th>Status</th></tr></thead><tbody>{rows}</tbody></table></section>"


def render_page(message=None, code=200, show_handled=False):
    vm = _build_view_model(show_handled=show_handled)
    now = datetime.datetime.now().astimezone().isoformat(timespec="seconds")

    msg_html = ""
    if message is not None:
        friendly = _friendly_summary(message, code)
        details_text = message.strip()
        cls = "ok" if code == 0 else "err"
        details = ""
        if details_text:
            details = f"<details><summary>Details</summary><pre>{esc(details_text)}</pre></details>"
        msg_html = f"<section class='{cls}'><h2>Last action</h2><p><strong>{esc(friendly)}</strong></p>{details}</section>"

    torrents_section = _render_torrents_section(vm["new_torrents"], vm["handled_torrents"], show_handled)
    pending_section = _render_pending_section(vm["pending_review"], vm["handled_review"], show_handled)
    attention_section = _render_attention_section(vm["attention_items"])

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
  .badge-done {{ background: #065f46; color: #a7f3d0; padding: .15rem .5rem; border-radius: 999px; font-size: .8rem; }}
  .badge-attention {{ background: #92400e; color: #fde68a; padding: .15rem .5rem; border-radius: 999px; font-size: .8rem; }}
  details {{ margin: .5rem 0; }} details summary {{ cursor: pointer; color: #93c5fd; }}
  details[open] summary {{ margin-bottom: .5rem; }}
</style></head><body>
<h1>Audiobook imports</h1>
<p>Updated: {esc(now)}</p>
{msg_html}
{torrents_section}
{pending_section}
{attention_section}
{_log_block('Recent imports', vm['imported_log'])}
{_log_block('Recent review copies', vm['reviewed_log'])}
<details><summary>Technical details</summary><p>Downloads: <code>{esc(TORRENT_DIR)}</code><br>Review area: <code>{esc(REVIEW_DIR)}</code><br>Library: <code>{esc(LIBRARY_DIR)}</code></p></details>
</body></html>"""


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


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path != "/":
            self.send_error(404)
            return
        params = urllib.parse.parse_qs(parsed.query)
        if set(params.keys()) - {"show"}:
            self.send_error(404)
            return
        show_handled = params.get("show", [""])[0] == "handled"
        self.respond(render_page(show_handled=show_handled))

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
