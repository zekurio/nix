{inputs, ...}: {
  flake.modules.nixos.lilith = {pkgs, ...}: let
    extensionUpdateUrl = "https://clients2.google.com/service/update2/crx";
    catppuccinChrome = pkgs.fetchFromGitHub {
      owner = "catppuccin";
      repo = "chrome";
      rev = "v5.0.0";
      hash = "sha256-SGGrLQtxmdVDNOQgz8fDmEIUB52o1lSIZ6Z3Fvrvrmg=";
    };
    catppuccinTheme = "${catppuccinChrome}/themes/frappe/blue";
    helium = pkgs.symlinkJoin {
      name = "helium-catppuccin-frappe-blue";
      paths = [inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/helium \
          --add-flags "--load-extension=${catppuccinTheme}"
      '';
    };
    extensions = [
      # Kagi Search
      "cdglnehniifkbagbbombnjghhcihifij"
      # Kagi Translate
      "alblebhaoakdgapamjdifdfnaicpnklm"
      # ChatGPT / Codex
      "hehggadaopoacecdllhhajmbjkdcmajg"
      # 1Password
      "aeblfdkhhhdcdjpifhhbdiojplfjncoa"
    ];
  in {
    environment = {
      systemPackages = [helium];

      # Helium is Chromium-based and reads its managed policies from here.
      etc."chromium/policies/managed/helium.json".text = builtins.toJSON {
        ExtensionInstallForcelist = map (id: "${id};${extensionUpdateUrl}") extensions;
      };
    };
  };
}
