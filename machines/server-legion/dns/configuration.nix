# Terranix module. records is the public routing map; credentials come from the provider environment.
{
  domain,
  records,
  providerVersion,
  ...
}:
{
  terraform = {
    backend.local.path = "terraform.tfstate";
    required_providers.cloudflare = {
      source = "cloudflare/cloudflare";
      version = providerVersion;
    };
  };
  provider.cloudflare = { };
  data.cloudflare_zone.legion.filter = {
    name = domain;
    status = "active";
  };
  resource.cloudflare_dns_record = builtins.mapAttrs (
    _: record:
    record
    // {
      zone_id = "\${data.cloudflare_zone.legion.id}";
      # Own routing, not dashboard annotations or provider-specific settings.
      lifecycle.ignore_changes = [
        "comment"
        "tags"
        "settings"
      ];
    }
  ) records;
}
