{inputs, ...}: {
  flake.modules.nixos.lilith = {pkgs, ...}: let
    catppuccinChrome = pkgs.fetchFromGitHub {
      owner = "catppuccin";
      repo = "chrome";
      rev = "v5.0.0";
      hash = "sha256-SGGrLQtxmdVDNOQgz8fDmEIUB52o1lSIZ6Z3Fvrvrmg=";
    };
    catppuccinTheme = "${catppuccinChrome}/themes/frappe/blue";
    heliumPackage = inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default;
    helium = pkgs.symlinkJoin {
      name = "helium-catppuccin-frappe-blue";
      paths = [heliumPackage];
      nativeBuildInputs = [pkgs.makeWrapper];
      # VA-API video decode (Chromium 151 + Mesa 26.2 radeonsi, RX 6800)
      # corrupts YouTube frames with shifting color blocks; fall back to
      # software decode until a Mesa/Chromium update fixes the VCN path.
      postBuild = ''
        # The upstream Nix wrapper adds --disable-background-networking,
        # which prevents Chromium's extension updater from installing both
        # policy-managed and manually requested extensions.
        rm $out/bin/helium
        cp ${heliumPackage}/bin/helium $out/bin/helium
        chmod +w $out/bin/helium
        substituteInPlace $out/bin/helium \
          --replace-fail " --disable-background-networking" ""

        wrapProgram $out/bin/helium \
          --add-flags "--load-extension=${catppuccinTheme}" \
          --add-flags "--disable-accelerated-video-decode"
      '';
    };
  in {
    # Helium currently cannot fetch force-installed extensions and then blocks
    # their manual installation as administrator-managed. Manage extensions in
    # the browser until https://github.com/imputnet/helium/issues/1737 is fixed.
    environment.systemPackages = [helium];
  };
}
