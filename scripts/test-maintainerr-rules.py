"""Validate the cleanup policy exported by Nix, optionally against live rule IDs.

Usage: python test-maintainerr-rules.py RULES_JSON [CONSTANTS_JSON]
The optional constants file is the GET /api/rules/constants response. This test
checks configuration, not Maintainerr's live eligibility or deletion behavior.
"""

import json
import sys


def validate(rules, constants=None):
    """Check destructive actions, grace periods, protections and eligibility."""
    expected = {
        "Cleanup - Movies watched": ("Movies", "movie", "Radarr"),
        "Cleanup - Movies never played": ("Movies", "movie", "Radarr"),
        "Cleanup - Shows completed": ("Shows", "show", "Sonarr"),
        "Cleanup - Anime completed": ("Anime", "show", "Sonarr Anime"),
    }
    assert len(rules) == 4
    assert {group["name"] for group in rules} == set(expected)
    for group in rules:
        library, media_type, server = expected[group["name"]]
        movie = media_type == "movie"
        assert group["library"] == library and group["dataType"] == media_type
        assert group["radarrServerName" if movie else "sonarrServerName"] == server
        assert group["isActive"] and group["useRules"]
        assert group["arrAction"] == 1  # UNMONITOR_DELETE_ALL
        assert group["forceSeerr"] is False and group["listExclusions"] is True
        assert group["collection"]["deleteAfterDays"] == 30
        assert group["collection"]["visibleOnHome"]
        assert group["collection"]["visibleOnRecommended"]
        assert not group["collection"]["manualCollection"]
        predicates = {}
        for index, rule in enumerate(group["rules"]):
            assert rule["section"] == 0
            assert rule["operator"] == (None if index == 0 else "0")
            key = tuple(rule["firstVal"])
            assert key not in predicates
            predicates[key] = rule

        def require(key, action, value_type, value):
            """Require an exact comparison, including literal units and type."""
            rule = predicates[key]
            assert rule["action"] == action and rule["lastVal"] is None
            assert rule["customVal"] == {"ruleTypeId": value_type, "value": str(value)}

        require((6, 39 if movie else 40), 14, 0, 0)  # No favorites
        require((1 if movie else 2, 2), 9, 2, "keep")  # No keep tag
        never_played = group["name"] == "Cleanup - Movies never played"
        require((6, 0), 5, 0, (365 if never_played else 180) * 86400)
        if movie:
            require((6, 42), 2, 3, 0 if never_played else 1)
            if never_played:
                require((6, 30), 2, 0, 0)
            else:
                require((6, 47), 5, 0, 180 * 86400)
            assert len(predicates) == 5
        else:
            require((2, 7), 2, 3, 1)  # Ended series only
            require((6, 14), 0, 0, 0)  # At least one available episode
            assert predicates[(6, 15)]["action"] == 2
            assert predicates[(6, 15)]["lastVal"] == [6, 14]
            assert predicates[(6, 15)]["customVal"] is None
            require((6, 16), 5, 0, 180 * 86400)
            require((6, 47), 5, 0, 180 * 86400)
            assert len(predicates) == 8

    if constants is not None:
        properties = {
            (app["id"], prop["id"]): prop
            for app in constants["applications"]
            for prop in app["props"]
        }
        names = {
            (1, 2): "tags", (2, 2): "tags", (2, 7): "ended",
            (6, 0): "addDate", (6, 14): "sw_episodes",
            (6, 15): "sw_viewedEpisodes", (6, 16): "sw_lastEpisodeAddedAt",
            (6, 30): "playCount", (6, 39): "favoritedBy",
            (6, 40): "sw_favoritedBy", (6, 42): "isWatched",
            (6, 47): "lastPlayedAt",
        }
        for key, name in names.items():
            assert properties[key]["name"] == name
        for group in rules:
            for rule in group["rules"]:
                prop = properties[tuple(rule["firstVal"])]
                assert rule["action"] in prop["type"]["possibilities"]
                if "showType" in prop and group["dataType"] == "show":
                    assert "show" in prop["showType"]


if __name__ == "__main__":
    with open(sys.argv[1], encoding="utf-8") as handle:
        policy = json.load(handle)
    live_constants = None
    if len(sys.argv) > 2:
        with open(sys.argv[2], encoding="utf-8") as handle:
            live_constants = json.load(handle)
    validate(policy, live_constants)
    print("Maintainerr cleanup policy checks passed")
