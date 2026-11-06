{
  pkgs,
  config,
  dns,
  openDesignConfig,
}:
{
  legion-dns = dns;
  legion-media-preferences =
    pkgs.runCommand "legion-media-preferences"
      {
        nativeBuildInputs = [ pkgs.python3 ];
      }
      ''
        export PYTHONDONTWRITEBYTECODE=1
        python -m unittest discover -s ${../services/media-quality} -p test.py
        touch "$out"
      '';
  legion-ingress = import ./ingress.nix { inherit pkgs config; };
  legion-oidc = import ../services/identity/check.nix { inherit pkgs config; };
  legion-beszel = import ../services/beszel/check.nix { inherit pkgs config; };
  legion-copyparty = import ../services/copyparty/check.nix { inherit pkgs config; };
  legion-forgejo = import ../services/forgejo/check.nix { inherit pkgs config; };
  legion-open-design = import ../services/open-design/check.nix {
    inherit pkgs;
    config = openDesignConfig;
  };
}
// pkgs.lib.optionalAttrs (config.services.gatus.enable && config.services.ntfy-sh.enable) {
  legion-monitoring = import ../services/gatus/check.nix { inherit pkgs config; };
}
