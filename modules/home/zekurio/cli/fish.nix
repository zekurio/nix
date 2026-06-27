{
  config,
  lib,
  pkgs,
  ...
}: let
  gitDirectory = "${config.home.homeDirectory}/Documents/Git";
  nixRepository = "${gitDirectory}/nix";
in {
  programs = {
    atuin = {
      enable = true;
      enableFishIntegration = true;
    };

    fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_greeting
      '';
      shellAbbrs = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        cgit = "cd ${gitDirectory}";
        cnix = "cd ${nixRepository}";
        nixcfg = "cd ${nixRepository}";
      };
      shellAliases = {
        ls = "eza";
        ll = "eza -lah";
        la = "eza -la";
        lt = "eza --tree";
        cat = "bat";
        codex = "command codex --dangerously-bypass-approvals-and-sandbox";
        claude = "command claude --dangerously-skip-permissions";
      };
    };

    carapace = {
      enable = true;
      enableFishIntegration = true;
    };

    zoxide = {
      enable = true;
      enableFishIntegration = true;
      options = [
        "--cmd"
        "cd"
      ];
    };
  };
}
