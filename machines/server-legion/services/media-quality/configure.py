"""Apply local custom formats to named profiles without touching media or queues."""

import copy
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.request

SUBTITLE_PATTERN = (
    r"\b(?:ENG(?:LISH)?[ ._-]*(?:SUBS?|SUBTITLES?)"
    r"|(?:SUBS?|SUBTITLES?)[ ._-]*ENG(?:LISH)?)\b"
)
FORMATS = [
    {
        "name": "[Legion] Original audio",
        "score": 1000,
        "specifications": [
            {
                "name": "Original language",
                "implementation": "LanguageSpecification",
                "negate": False,
                "required": False,
                "fields": [
                    {"name": "value", "value": -2},
                    {"name": "exceptLanguage", "value": False},
                ],
            }
        ],
    },
    {
        "name": "[Legion] English subtitles advertised",
        "score": 100,
        "specifications": [
            {
                "name": "Explicit English subtitle claim",
                "implementation": "ReleaseTitleSpecification",
                "negate": False,
                "required": False,
                "fields": [{"name": "value", "value": SUBTITLE_PATTERN}],
            }
        ],
    },
]


def unique_named(rows, name):
    """Return exactly one matching resource; never fall back to a default profile."""
    matches = [row for row in rows if row["name"] == name]
    if len(matches) != 1:
        raise RuntimeError("Expected one named media configuration resource")
    return matches[0]


def canonical_format(resource):
    """Remove API-generated UI metadata when comparing owned format definitions."""
    return {
        "name": resource["name"],
        "includeCustomFormatWhenRenaming": resource.get(
            "includeCustomFormatWhenRenaming", False
        ),
        "specifications": [
            {
                **{key: spec[key] for key in ("name", "implementation", "negate", "required")},
                "fields": sorted(
                    [{"name": f["name"], "value": f.get("value")} for f in spec["fields"]],
                    key=lambda field: field["name"],
                ),
            }
            for spec in resource["specifications"]
        ],
    }


def scored_profile(profile, formats):
    """Change only owned scores and Radarr's language selector on the named profile."""
    result = copy.deepcopy(profile)
    scores = {fmt["id"]: fmt["score"] for fmt in formats}
    present = {item["format"] for item in result["formatItems"]}
    if not scores.keys() <= present:
        raise RuntimeError("Owned custom formats are missing from the profile")
    for item in result["formatItems"]:
        if item["format"] in scores:
            item["score"] = scores[item["format"]]
    # Original audio is a preference, not a hard ban on unknown-language releases.
    if "language" in result:
        result["language"] = {"id": -1, "name": "Any"}
    return result


def client(base_url, key):
    """Return an API client that keeps keys and JSON bodies out of process arguments."""
    def request(method, resource, body=None):
        payload = None if body is None else json.dumps(body).encode()
        req = urllib.request.Request(
            base_url + "/" + resource,
            data=payload,
            headers={"X-Api-Key": key, "Content-Type": "application/json"},
            method=method,
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                data = response.read()
        except urllib.error.HTTPError as exc:
            raise RuntimeError(f"Media configuration API returned HTTP {exc.code}") from None
        return json.loads(data) if data else None
    return request


def configure(instance, credential_dir):
    """Upsert owned formats and scores through the instance's authenticated API."""
    key = (credential_dir / instance["name"]).read_text().strip()
    request = client(instance["url"], key)

    # Fail before creating anything if Recyclarr has not created the target profile.
    unique_named(request("GET", "qualityprofile"), instance["profile"])
    existing = request("GET", "customformat")
    for fmt in FORMATS:
        desired = {k: v for k, v in fmt.items() if k != "score"}
        desired["includeCustomFormatWhenRenaming"] = False
        matches = [row for row in existing if row["name"] == fmt["name"]]
        if not matches:
            request("POST", "customformat", desired)
        else:
            current = unique_named(existing, fmt["name"])
            if canonical_format(current) != canonical_format(desired):
                request("PUT", f"customformat/{current['id']}", {**desired, "id": current["id"]})
    existing = request("GET", "customformat")
    formats = [{**unique_named(existing, fmt["name"]), "score": fmt["score"]} for fmt in FORMATS]
    profile = unique_named(request("GET", "qualityprofile"), instance["profile"])
    updated = scored_profile(profile, formats)
    if updated != profile:
        request("PUT", f"qualityprofile/{profile['id']}", updated)


def configure_seerr(settings, kind, credential_dir):
    """Select profiles for future Seerr requests while preserving connection settings."""
    request = client(settings["seerrUrl"], (credential_dir / "seerr").read_text().strip())
    servers = request("GET", "settings/" + kind)
    for instance in settings["instances"]:
        if not instance["name"].startswith(kind):
            continue
        server = unique_named(servers, instance["seerrName"])
        key = (credential_dir / instance["name"]).read_text().strip()
        arr = client(instance["url"], key)
        profile = unique_named(arr("GET", "qualityprofile"), instance["profile"])
        updated = copy.deepcopy(server)
        updated["activeProfileId"] = profile["id"]
        updated["activeProfileName"] = profile["name"]
        if kind == "sonarr":
            updated["activeAnimeProfileId"] = profile["id"]
            updated["activeAnimeProfileName"] = profile["name"]
        if updated != server:
            body = {k: v for k, v in updated.items() if k != "id"}
            request("PUT", f"settings/{kind}/{server['id']}", body)


def main():
    """Load public configuration, private systemd credentials and provisioning mode."""
    settings = json.loads(Path(sys.argv[1]).read_text())
    credential_dir = Path(os.environ["CREDENTIALS_DIRECTORY"])
    if len(sys.argv) == 2:
        for instance in settings["instances"]:
            configure(instance, credential_dir)
    elif sys.argv[2] in ("seerr-radarr", "seerr-sonarr"):
        configure_seerr(settings, sys.argv[2].removeprefix("seerr-"), credential_dir)
    else:
        raise RuntimeError("Unknown media provisioning mode")
    print("Configured named media-selection profiles")


if __name__ == "__main__":
    main()
