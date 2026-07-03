{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  gitDirectory = "${config.home.homeDirectory}/Documents/Git";
  nixRepository = "${gitDirectory}/nix";
  system = pkgs.stdenv.hostPlatform.system;
  codex = inputs.llm-agents.packages.${system}.codex;
  claude = inputs.llm-agents.packages.${system}.claude-code;
in {
  home.file = lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) {
    ".local/bin/codex" = {
      executable = true;
      text = ''
        #!${pkgs.runtimeShell}
        exec ${codex}/bin/codex --dangerously-bypass-approvals-and-sandbox "$@"
      '';
    };
    ".local/bin/claude" = {
      executable = true;
      text = ''
        #!${pkgs.runtimeShell}
        exec ${claude}/bin/claude --dangerously-skip-permissions "$@"
      '';
    };
  };

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
      shellAliases =
        {
          ls = "eza";
          ll = "eza -lah";
          la = "eza -la";
          lt = "eza --tree";
          cat = "bat";
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          codex = "codex --dangerously-bypass-approvals-and-sandbox";
          claude = "claude --dangerously-skip-permissions";
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
