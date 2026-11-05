"""Focused tests for local selection rules and preservation of unrelated settings."""

import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from configure import FORMATS, SUBTITLE_PATTERN, canonical_format, configure_seerr, scored_profile, unique_named


class MediaPreferencesTest(unittest.TestCase):
    def test_subtitle_claims(self):
        for suffix in ["ENGSUB", "ENG.SUBS", "English.Subtitles", "SUBS-ENG"]:
            with self.subTest(suffix=suffix):
                self.assertRegex("Example.1080p." + suffix, re.compile(SUBTITLE_PATTERN, re.I))
        for suffix in ["ENGLISH", "DUAL.AUDIO", "MULTI", "SUBFRENCH", "ENG.DUB"]:
            with self.subTest(suffix=suffix):
                self.assertNotRegex("Example.1080p." + suffix, re.compile(SUBTITLE_PATTERN, re.I))

    def test_scores_preserve_other_fields(self):
        profile = {"id": 8, "name": "Legion Movies 1080p", "upgradeAllowed": True,
                   "language": {"id": -2, "name": "Original"},
                   "formatItems": [{"format": 1, "score": 7}, {"format": 2, "score": 0}]}
        result = scored_profile(profile, [{"id": 2, "score": 100}])
        self.assertEqual(result["formatItems"], [{"format": 1, "score": 7}, {"format": 2, "score": 100}])
        self.assertEqual(result["id"], profile["id"])
        self.assertTrue(result["upgradeAllowed"])
        self.assertEqual(result["language"]["id"], -1)
        self.assertEqual(profile["formatItems"][1]["score"], 0)
        self.assertEqual(profile["language"]["id"], -2)
        with self.assertRaises(RuntimeError):
            scored_profile(profile, [{"id": 99, "score": 100}])

    def test_named_resource_fails_closed(self):
        for rows in [[], [{"name": "Any"}], [{"name": "Target"}, {"name": "Target"}]]:
            with self.assertRaises(RuntimeError):
                unique_named(rows, "Target")
        self.assertEqual(unique_named([{"name": "Target", "id": 8}], "Target")["id"], 8)

    def test_seerr_changes_only_profile_selection(self):
        server = {"id": 0, "name": "Radarr", "apiKey": "fixture", "hostname": "unchanged",
                  "activeProfileId": 1, "activeProfileName": "Any", "preventSearch": False}
        writes = []

        def seerr(method, resource, body=None):
            if method == "GET":
                return [server]
            writes.append((method, resource, body))

        def arr(method, resource, body=None):
            return [{"id": 8, "name": "Target"}]

        settings = {"seerrUrl": "seerr", "instances": [
            {"name": "radarr", "url": "arr", "profile": "Target", "seerrName": "Radarr"}]}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ["seerr", "radarr"]:
                (root / name).write_text("fixture")
            with patch("configure.client", side_effect=lambda url, key: seerr if url == "seerr" else arr):
                configure_seerr(settings, "radarr", root)
        self.assertEqual(len(writes), 1)
        method, resource, body = writes[0]
        self.assertEqual((method, resource), ("PUT", "settings/radarr/0"))
        expected = {**server, "activeProfileId": 8, "activeProfileName": "Target"}
        expected.pop("id")
        self.assertEqual(body, expected)
        self.assertEqual(server["activeProfileId"], 1)

    def test_api_metadata_does_not_cause_repeated_updates(self):
        definition = {k: v for k, v in FORMATS[0].items() if k != "score"}
        rendered = {**definition, "id": 50, "includeCustomFormatWhenRenaming": False}
        self.assertEqual(canonical_format(definition), canonical_format(rendered))


if __name__ == "__main__":
    unittest.main()
