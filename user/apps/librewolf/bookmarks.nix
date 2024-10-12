# List of bookmarks, either in the toolbar or in the menu.
# See the expected format here: https://github.com/mozilla/policy-templates/blob/master/linux/policies.json#L33.
# The favicon are provided by a public API service, see https://stackoverflow.com/questions/46369862/get-the-favicon-of-a-url-and-display-it-firefox-web-ext.
{ lib }:
let
  # The following are functions that extract the domain name from an url and
  # use it to get the corresponding favicon with the API service.
  prefixes = [
    "https://"
    "http://"
  ];
  removePrefixes = url: lib.foldr (prefix: str: lib.strings.removePrefix prefix str) url prefixes;
  extractDomainName = url: lib.lists.head (lib.strings.split "/" (removePrefixes url));
  getFavicon = url: "https://icon.horse/icon/${extractDomainName url}"; # See https://icon.horse/.
  addFavicon = attrset: attrset // { "Favicon" = getFavicon attrset."URL"; };

  bookmarks = [
    {
      "Title" = "Nixpkgs";
      "URL" = "https://search.nixos.org/";
      "Placement" = "toolbar";
    }
    {
      "Title" = "";
      "URL" = "https://github.com";
      "Placement" = "toolbar";
    }
  ];
in
builtins.map addFavicon bookmarks
