{
  inputs,
  pkgs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  chromeWebStoreUpdateUrl = "https://clients2.google.com/service/update2/crx";
  extensionIds = [
    "alblebhaoakdgapamjdifdfnaicpnklm" # Kagi Translate
    "cdglnehniifkbagbbombnjghhcihifij" # Kagi Search
    "nngceckbapebfimnlniiiahkandclblb" # Bitwarden Password Manager
    "lppmekppnliemjclknbagdhoocikieoi" # 7TV
  ];
in {
  environment.systemPackages = [
    inputs.helium.packages.${system}.default
  ];

  programs.chromium = {
    enable = true;
    extensions = map (id: "${id};${chromeWebStoreUpdateUrl}") extensionIds;
  };
}
