{
  nixpkgs.overlays = [
    (final: prev: {
      _1password-gui = prev._1password-gui.overrideAttrs (old: {
        src = prev.fetchurl {
          inherit (old.src) url;
          hash = "sha256-JwiMi2iozP6jWSIUtgXla86aSAhuUob7snqtUbeXPpI=";
        };
      });
    })
  ];
}
