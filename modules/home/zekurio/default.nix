{
  inputs,
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
    ./pi
  ];

  config = {
    catppuccin = {
      flavor = "frappe";
      accent = "mauve";
      fish.enable = true;
      ghostty.enable = true;
      zellij.enable = true;
    };

    home.pi = {
      enable = true;
      settings = {
        theme = "catppuccin-frappe";
        quietStartup = true;
        enableInstallTelemetry = false;
        packages = [
          "git:github.com/mjakl/pi-kagi-api"
        ];
        extensions = [
          "./extensions/fast.ts"
          "./extensions/goal"
        ];
      };
      keybindings = {
        "app.clipboard.pasteImage" = [
          "ctrl+v"
          "alt+v"
        ];
        "app.thinking.cycle" = ["ctrl+r"];
      };
      contextFiles."extensions/fast.ts" = builtins.readFile ./pi/extensions/fast.ts;
    };

    home.file.".pi/agent/extensions/goal" = {
      source = ./pi/extensions/goal;
      recursive = true;
    };

    home.file.".pi/agent/themes/catppuccin-frappe.json".source = "${inputs.pi-catppuccin.packages.${pkgs.stdenv.hostPlatform.system}.default}/share/pi/themes/catppuccin-frappe.json";

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
