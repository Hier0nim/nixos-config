# Test routing and protected names before validating generated JSON with the pinned provider.
{
  pkgs,
  directTarget,
  mkRecords,
  configuration,
  tools,
}:
let
  base = {
    domain = "pieczarkowo.me";
    enableTunnel = false;
    tunnelId = null;
    services = {
      native.transport = "direct";
      selected.transport = "tunnel";
    };
  };
  render =
    overrides:
    mkRecords {
      inherit directTarget;
      ingress = base // overrides;
    };
  rejects = overrides: !(builtins.tryEval (builtins.deepSeq (render overrides) true)).success;
  direct = render { };
  active = render {
    enableTunnel = true;
    tunnelId = "12345678-1234-4abc-8def-123456789abc";
  };
  removed = render {
    services = {
      native.transport = "direct";
    };
  };
  added = render {
    services = base.services // {
      future.transport = "direct";
    };
  };
in
assert direct.native.content == directTarget && !direct.native.proxied;
assert direct.selected.content == directTarget && !direct.selected.proxied;
assert direct.native.ttl == 1 && direct.selected.type == "CNAME";
assert active.native == direct.native;
assert active.selected.content == "12345678-1234-4abc-8def-123456789abc.cfargotunnel.com";
assert active.selected.proxied;
assert builtins.attrNames removed == [ "native" ];
assert added.native == direct.native && added.selected == direct.selected;
assert added.future.name == "future.pieczarkowo.me";
assert rejects { enableTunnel = true; };
assert rejects {
  enableTunnel = true;
  tunnelId = "<TUNNEL_UUID>";
};
assert rejects {
  enableTunnel = true;
  tunnelId = "00000000-0000-0000-0000-000000000000";
};
assert rejects {
  services = {
    ha.transport = "direct";
  };
};
assert rejects {
  services = {
    "*".transport = "tunnel";
  };
};
assert rejects {
  services = {
    "_acme-challenge".transport = "direct";
  };
};
assert rejects {
  services = {
    "selector._domainkey".transport = "direct";
  };
};
assert rejects { domain = "another-zone.example"; };
pkgs.runCommand "legion-dns-generation-check"
  {
    nativeBuildInputs = [ tools ];
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    export CHECKPOINT_DISABLE=1 TF_IN_AUTOMATION=1
    install -m 0600 ${configuration} main.tf.json
    tofu init -backend=false -input=false -no-color
    tofu validate -no-color
    touch "$out"
  ''
