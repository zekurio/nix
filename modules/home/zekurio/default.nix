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
    ./desktop
    ./git
    ./pi
  ];

  config = {
    home.pi = {
      enable = true;
      settings = {
        theme = "dark";
        quietStartup = true;
        enableInstallTelemetry = false;
        extensions = [
          "./extensions/fast.ts"
          "./extensions/goal"
        ];
      };
      keybindings = {
        "app.thinking.cycle" = ["ctrl+r"];
      };
      contextFiles."extensions/fast.ts" = builtins.readFile ./pi/extensions/fast.ts;
    };

    home.file.".pi/agent/extensions/goal" = {
      source = ./pi/extensions/goal;
      recursive = true;
    };

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
