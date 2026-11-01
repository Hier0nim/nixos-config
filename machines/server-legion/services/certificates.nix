{
  config,
  pkgs,
  ...
}:
let
  domain = "pieczarkowo.me";
  tokenFile = config.clan.core.vars.generators.cloudflare-dns.files."api-token".path;
in
{
  clan.core.vars.generators.cloudflare-dns = {
    files."api-token" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    prompts."api-token" = {
      description = "Cloudflare API token with Zone Read and DNS Edit restricted to pieczarkowo.me";
      type = "hidden";
    };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      test -s "$prompts/api-token"
      install -m 0400 "$prompts/api-token" "$out/api-token"
    '';
  };

  # Issue and renew the certificate before switching Caddy to use it.
  security.acme = {
    acceptTerms = true;
    certs.${domain} = {
      inherit domain;
      email = "hieronimdaniel@proton.me";
      extraDomainNames = [ "*.${domain}" ];
      dnsProvider = "cloudflare";
      dnsResolver = "1.1.1.1:53";
      dnsPropagationCheck = true;
      group = "caddy";
      credentialFiles.CLOUDFLARE_DNS_API_TOKEN_FILE = tokenFile;
    };
  };
}
