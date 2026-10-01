{inputs, ...}: {
  flake.modules.nixos.lilith = {pkgs, ...}: let
    heliumPackage = inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default;
    helium = pkgs.symlinkJoin {
      name = "helium";
      paths = [heliumPackage];
      postBuild = ''
        # The upstream wrapper disables background networking, which also
        # prevents Chromium's extension updater from installing extensions.
        rm "$out/bin/helium"
        cp ${heliumPackage}/bin/helium "$out/bin/helium"
        chmod +w "$out/bin/helium"
        substituteInPlace "$out/bin/helium" \
          --replace-fail " --disable-background-networking" ""
      '';
    };
  in {
    environment.systemPackages = [helium];
  };
}
