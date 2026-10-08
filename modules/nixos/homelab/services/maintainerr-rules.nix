# Maintainerr 3.30.1 rule IDs from its rules.constants.ts (Jellyfin=6, Radarr=1,
# Sonarr=2). Keep the numeric mapping covered by checks when upgrading Maintainerr.
{ lib }:
let
  # Compare a source property against a typed literal. Relative dates use seconds,
  # not days; ruleTypeId=0 is numeric, 2 is text, and 3 is boolean.
  compare = firstVal: action: ruleTypeId: value: {
    inherit firstVal action;
    customVal = {
      inherit ruleTypeId;
      value = toString value;
    };
  };
  olderThan = property: days: compare property "BEFORE" 0 (days * 24 * 60 * 60);
  equalsBool = property: value: compare property "EQUALS" 3 (if value then 1 else 0);

  # A single AND section prevents an age condition bypassing keep protections.
  allOf = lib.imap0 (
    index: rule:
    rule
    // {
      section = 0;
      operator = if index == 0 then null else "0";
    }
  );

  # Favorites apply to the movie or series itself, not favorite child episodes.
  protections = isMovie: [
    (compare [
      6
      (if isMovie then 39 else 40)
    ] "COUNT_EQUALS" 0 0)
    (compare [
      (if isMovie then 1 else 2)
      2
    ] "NOT_CONTAINS" 2 "keep")
  ];

  # Retain the Arr record, but unmonitor it and delete its files after 30 days.
  # Explicit server associations prevent fallback deletion through Jellyfin.
  collection = {
    visibleOnHome = true;
    visibleOnRecommended = true;
    deleteAfterDays = 30;
    overlayEnabled = false;
    keepLogsForMonths = 6;
  };
  common = {
    inherit collection;
    isActive = true;
    useRules = true;
    arrAction = "UNMONITOR_DELETE_ALL";
    forceSeerr = false;
    listExclusions = true;
  };

  # Whole-series cleanup requires an ended show and all available episodes seen.
  # The watched episode count aggregates completion across Jellyfin users.
  completedSeries =
    library: sonarrServerName:
    common
    // {
      name = "Cleanup - ${library} completed";
      description = "Ended series with every available episode watched, no playback or new episodes for 180 days. Files are deleted and the series unmonitored after 30 days. Favorite the SERIES or add an Arr keep tag to protect it.";
      inherit library sonarrServerName;
      dataType = "show";
      rules = allOf (
        protections false
        ++ [
          (equalsBool [ 2 7 ] true) # Sonarr: show ended
          (compare [ 6 14 ] "BIGGER" 0 0) # Jellyfin: available episode count
          {
            firstVal = [
              6
              15
            ]; # Jellyfin: watched episode count
            action = "EQUALS";
            lastVal = [
              6
              14
            ];
          }
          (olderThan [ 6 0 ] 180) # Jellyfin: date added
          (olderThan [ 6 16 ] 180) # Jellyfin: newest episode added
          (olderThan [ 6 47 ] 180) # Jellyfin: latest play, including unfinished
        ]
      );
    };
in
[
  (
    common
    // {
      name = "Cleanup - Movies watched";
      description = "Watched by a Jellyfin user, present for 180 days and not played for 180 days. Files are deleted and the movie unmonitored after 30 days. Favorites and the Radarr keep tag are protected.";
      library = "Movies";
      dataType = "movie";
      radarrServerName = "Radarr";
      rules = allOf (
        protections true
        ++ [
          (equalsBool [ 6 42 ] true) # Jellyfin: shared watched state
          (olderThan [ 6 0 ] 180)
          (olderThan [ 6 47 ] 180)
        ]
      );
    }
  )
  (
    common
    // {
      name = "Cleanup - Movies never played";
      description = "Present for 365 days, not marked watched and with no play attempts. Files are deleted and the movie unmonitored after 30 days. Favorites and the Radarr keep tag are protected.";
      library = "Movies";
      dataType = "movie";
      radarrServerName = "Radarr";
      rules = allOf (
        protections true
        ++ [
          (equalsBool [ 6 42 ] false)
          (compare [ 6 30 ] "EQUALS" 0 0) # Includes unfinished play attempts
          (olderThan [ 6 0 ] 365)
        ]
      );
    }
  )
  (completedSeries "Shows" "Sonarr")
  (completedSeries "Anime" "Sonarr Anime")
]
