{
  nixpkgs.overlays = [
    (final: prev: {
      _1password-gui = prev._1password-gui.overrideAttrs (old: {
        src = prev.fetchurl {
          inherit (old.src) url;
          hash = "sha256-dec+oqixlPAbHYWqOBEBNB9IU8+Hfz2W4bm1y6/CbuM=";
        };
      });
    })
  ];
}
