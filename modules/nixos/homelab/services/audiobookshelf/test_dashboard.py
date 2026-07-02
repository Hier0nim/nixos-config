"""Smoke tests for audiobook dashboard functions. No networking required."""
import importlib.util
import os
import sys


def main():
    spec = importlib.util.spec_from_file_location("dashboard", sys.argv[1])
    assert spec is not None and spec.loader is not None
    d = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(d)

    # scan_dir finds items
    torrents = d.scan_torrents()
    names = [i["name"] for i in torrents]
    assert "Torrent Book" in names, f"Torrent Book not in {names}"
    assert "Handled Torrent" in names, f"Handled Torrent not in {names}"

    pending = d.scan_pending()
    names = [i["name"] for i in pending]
    assert "Book One" in names, f"Book One not in {names}"
    assert "Handled Torrent" in names, f"Handled Torrent not in {names}"

    # view model: new torrent vs handled
    vm = d._build_view_model()
    new_names = [i["name"] for i in vm["new_torrents"]]
    assert "Torrent Book" in new_names, f"Torrent Book not in new_torrents: {new_names}"
    handled_names = [s[0]["name"] for s in vm["handled_torrents"]]
    assert "Handled Torrent" in handled_names, f"Handled Torrent not in handled: {handled_names}"
    assert "Renamed Torrent" in handled_names, f"Renamed Torrent not in handled: {handled_names}"

    # attention: none expected
    attention_names = [s[0]["name"] for s in vm["attention_items"]]
    assert "Handled Torrent" not in attention_names, f"Handled Torrent wrongly in attention: {attention_names}"
    assert "Renamed Torrent" not in attention_names, f"Renamed Torrent wrongly in attention: {attention_names}"

    # review status detection
    review_new = [i["name"] for i in vm["pending_review"]]
    assert "Book One" in review_new, f"Book One not in pending_review: {review_new}"
    review_handled = [s[0]["name"] for s in vm["handled_review"]]
    assert "Handled Torrent" in review_handled, f"Handled Torrent not in handled_review: {review_handled}"

    # render_page: default hides handled
    html = d.render_page()
    assert "Book One" in html
    assert "Torrent Book" in html
    assert "New downloads" in html
    assert "Ready to add to library" in html
    assert "Not running as root" not in html, "Technical noise leaked"
    assert "Show already handled" in html
    assert "Already in library" not in html, "Already in library visible by default"

    # render_page: show_handled reveals handled
    html2 = d.render_page(show_handled=True)
    assert "Already handled" in html2 or "Already in library" in html2
    assert "Hide already handled" in html2

    # safe_child / safe_destination
    path = d.safe_child(os.environ["AUDIOBOOK_TORRENT_DIR"], "Torrent Book")
    assert os.path.isdir(path)
    try:
        d.safe_child(os.environ["AUDIOBOOK_TORRENT_DIR"], "../etc")
        assert False, "should have raised"
    except ValueError:
        pass
    assert d.safe_destination("Author/Title") == "Author/Title"
    assert d.safe_destination("") == ""
    try:
        d.safe_destination("/etc")
        assert False, "should have raised"
    except ValueError:
        pass

    # _friendly_summary
    assert d._friendly_summary("Dry run only; no files changed.", 0) == "Preview complete. Nothing was changed."
    assert d._friendly_summary("Imported.", 0) == "Import complete."
    assert d._friendly_summary("Destination already exists: /foo", 1) == "That destination already exists. Choose a different name."

    print("All dashboard tests passed.")


if __name__ == "__main__":
    main()
