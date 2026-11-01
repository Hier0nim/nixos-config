#!/usr/bin/env python3
"""Apply the host's Listenarr settings through its local API."""

import http.cookiejar
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

API = os.environ["LISTENARR_API"].rstrip("/")
LIBRARY_DIR = os.environ["LISTENARR_LIBRARY_DIR"]
DOWNLOAD_DIR = os.environ["LISTENARR_DOWNLOAD_DIR"]
QB_HOST = os.environ["LISTENARR_QBITTORRENT_HOST"]
PROWLARR_HOST = os.environ["LISTENARR_PROWLARR_HOST"]
QB_CLIENT_ID = "00000000-0000-4000-8000-000000000001"
QB_CLIENT_NAME = "Legion qBittorrent"
UNSAFE_METHODS = {"DELETE", "PATCH", "POST", "PUT"}
COOKIE_JAR = http.cookiejar.CookieJar()
OPENER = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(COOKIE_JAR))
CSRF_TOKEN = None


def request_json(method, path, payload=None):
    """Call the local Listenarr API without logging request or response bodies."""
    global CSRF_TOKEN
    if method in UNSAFE_METHODS and CSRF_TOKEN is None:
        CSRF_TOKEN = request_json("GET", "/antiforgery/token")["token"]

    body = None if payload is None else json.dumps(payload).encode()
    headers = {"Content-Type": "application/json"}
    if method in UNSAFE_METHODS:
        headers["X-XSRF-TOKEN"] = CSRF_TOKEN
    request = urllib.request.Request(
        f"{API}{path}",
        data=body,
        headers=headers,
        method=method,
    )
    try:
        with OPENER.open(request, timeout=20) as response:
            content = response.read()
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"Listenarr API returned HTTP {error.code} for {method} {path}") from None
    except urllib.error.URLError as error:
        raise RuntimeError(f"Listenarr API request failed for {method} {path}: {error.reason}") from None
    return json.loads(content) if content else None


def wait_for_api():
    """Wait for Listenarr to finish starting before applying configuration."""
    for _ in range(60):
        try:
            request_json("GET", "/configuration/bootstrap")
            return
        except RuntimeError:
            time.sleep(2)
    raise RuntimeError("Listenarr API did not become ready")


def configure_root_folder():
    """Create or reconcile the default Audiobooks root without moving files."""
    folders = request_json("GET", "/rootfolders")
    folder = next((item for item in folders if item["path"] == LIBRARY_DIR), None)
    if folder is None:
        if any(item["name"] == "Audiobooks" for item in folders):
            raise RuntimeError("Listenarr already has an Audiobooks root at a different path")
        request_json(
            "POST",
            "/rootfolders",
            {
                "name": "Audiobooks",
                "path": LIBRARY_DIR,
                "isDefault": True,
                "caseSensitivityMode": "Sensitive",
            },
        )
        return

    request_json(
        "PUT",
        f"/rootfolders/{folder['id']}",
        {
            "id": folder["id"],
            "name": "Audiobooks",
            "path": LIBRARY_DIR,
            "isDefault": True,
            "caseSensitivityMode": "Sensitive",
        },
    )


def configure_application_settings():
    """Set the library output and retain qBittorrent files for seeding."""
    settings = request_json("GET", "/configuration/settings")
    settings["outputPath"] = LIBRARY_DIR
    settings["completedFileAction"] = "copy"
    settings["showCompletedExternalDownloads"] = True
    settings["defaultSearchLanguage"] = "all"
    request_json("POST", "/configuration/settings", settings)


def configure_quality_profile():
    """Maintain a permissive default profile for requests in any language."""
    profiles = request_json("GET", "/qualityprofile")
    existing = next((profile for profile in profiles if profile["name"] == "Legion default"), None)
    profile = {
        **(existing or {"qualities": []}),
        "name": "Legion default",
        "description": "Nix-managed default for Legion audiobook requests.",
        "cutoffQuality": None,
        "minimumSize": 0,
        "maximumSize": 0,
        "preferredFormats": ["m4b", "mp3", "m4a", "flac", "opus"],
        "preferredWords": [],
        "mustNotContain": [],
        "mustContain": [],
        "preferredLanguages": [],
        "minimumSeeders": 1,
        "minimumScore": 0,
        "isDefault": True,
        "preferNewerReleases": True,
        "maximumAge": 0,
        "customGroupNames": {},
    }
    if existing:
        request_json("PUT", f"/qualityprofile/{existing['id']}", profile)
    else:
        request_json("POST", "/qualityprofile", profile)
        request_json("GET", "/qualityprofile/default")


def configure_qbittorrent():
    """Configure and test qBittorrent using the machine-scoped Clan credential."""
    clients = request_json("GET", "/download-clients")
    existing = next((client for client in clients if client["name"] == QB_CLIENT_NAME), None)
    password = Path(os.environ["CREDENTIALS_DIRECTORY"], "qbittorrent-password").read_text().rstrip("\r\n")
    client = {
        "id": existing["id"] if existing else QB_CLIENT_ID,
        "name": QB_CLIENT_NAME,
        "type": "qbittorrent",
        "host": QB_HOST,
        "port": 8080,
        "username": "admin",
        "password": password,
        "downloadPath": DOWNLOAD_DIR,
        "useSSL": False,
        "isEnabled": True,
        "removeCompletedDownloads": "none",
        "settings": {"category": "audiobooks"},
    }

    for _ in range(30):
        result = request_json("POST", "/download-clients/test", client)
        if result and result.get("success") is True:
            break
        time.sleep(2)
    else:
        raise RuntimeError("Listenarr could not connect to qBittorrent; check its service and Clan password")

    request_json("POST", "/download-clients", client)


def import_prowlarr_indexers():
    """Import audiobook-category indexers from the machine's Prowlarr instance."""
    api_key = Path(os.environ["CREDENTIALS_DIRECTORY"], "prowlarr-api-key").read_text().rstrip("\r\n")
    payload = {
        "url": f"http://{PROWLARR_HOST}",
        "port": 9696,
        "clearPort": False,
        "apiKey": api_key,
        "tagFilter": "",
    }
    for _ in range(30):
        try:
            request_json("POST", "/indexers/prowlarr/import", payload)
            return
        except RuntimeError:
            time.sleep(2)
    raise RuntimeError("Listenarr could not import indexers from Prowlarr")


def main():
    wait_for_api()
    configure_root_folder()
    configure_application_settings()
    configure_quality_profile()
    configure_qbittorrent()
    import_prowlarr_indexers()
    print("Listenarr configuration applied")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, KeyError, ValueError, TypeError) as error:
        print(f"Listenarr configuration failed: {error}", file=sys.stderr)
        sys.exit(1)
