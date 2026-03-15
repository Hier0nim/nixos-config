/*
  final: prev: {
    cosmic-comp = prev.cosmic-comp.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ./cosmic-comp/no_ssd.patch
      ];
    });
  }
*/

final: prev: { }
