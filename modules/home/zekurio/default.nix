{
  lib,
  pkgs,
  ...
}: let
  homeDirectory =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "/Users/zekurio"
    else "/home/zekurio";
in {
  imports = [
    ./cli
    ./git
  ];

  config = {
    home = {
      username = lib.mkDefault "zekurio";
      homeDirectory = lib.mkDefault homeDirectory;
      stateVersion = lib.mkDefault "25.05";
      enableNixpkgsReleaseCheck = lib.mkDefault false;
      sessionPath = [
        "$HOME/.local/bin"
      ];
      sessionVariables = {
        SOPS_AGE_KEY_FILE = "${homeDirectory}/.config/sops/age/keys.txt";
      };
    };

    fonts.fontconfig.enable = false;
  };
}
