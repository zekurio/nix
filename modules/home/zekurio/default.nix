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
    ./dev.nix
    ./fish.nix
    ./git.nix
    ./packages.nix
    ./prompt.nix
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
    };

    fonts.fontconfig.enable = false;
  };
}
