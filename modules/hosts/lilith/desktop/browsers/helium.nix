{
  inputs,
  pkgs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  extensionIds = [
    "alblebhaoakdgapamjdifdfnaicpnklm" # Kagi Translate
    "cdglnehniifkbagbbombnjghhcihifij" # Kagi Search
    "nngceckbapebfimnlniiiahkandclblb" # Bitwarden Password Manager
    "lppmekppnliemjclknbagdhoocikieoi" # 7TV
    "olhelnoplefjdmncknfphenjclimckaf" # Catppuccin Chrome Theme - Frappe
  ];
in {
  environment.systemPackages = [
    inputs.helium.packages.${system}.default
  ];

  programs.chromium = {
    enable = true;
    extraOpts = {
      ExtensionInstallAllowlist = extensionIds;
      ExtensionInstallBlocklist = ["*"];
      ExtensionInstallForcelist = extensionIds;
      ExtensionInstallSources = ["https://services.helium.imput.net/*"];
    };
  };
}
