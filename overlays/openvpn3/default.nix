final: prev: {
  openvpn3 = prev.openvpn3.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./fix-openvpn3.patch
    ];
  });
}
