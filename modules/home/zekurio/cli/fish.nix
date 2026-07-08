{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  gitDirectory = "${config.home.homeDirectory}/Git";
  nixRepository = "${gitDirectory}/nix";
  system = pkgs.stdenv.hostPlatform.system;
  claude = inputs.llm-agents.packages.${system}.claude-code;
  codex = inputs.llm-agents.packages.${system}.codex;
in {
  home.file = lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) {
    ".local/bin/claude" = {
      executable = true;
      text = ''
        #!${pkgs.runtimeShell}
        exec ${claude}/bin/claude --dangerously-skip-permissions "$@"
      '';
    };
    ".local/bin/codex" = {
      executable = true;
      text = ''
        #!${pkgs.runtimeShell}
        exec ${codex}/bin/codex --dangerously-bypass-approvals-and-sandbox "$@"
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
      functions.omp = {
        body = ''
          command omp --allow-home $argv
        '';
      };
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
          claude = "claude --dangerously-skip-permissions";
          codex = "codex --dangerously-bypass-approvals-and-sandbox";
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

  # Fish colors come from catppuccin/nix, which installs the Frappé theme and
  # selects it with `fish_config theme choose`.
  catppuccin.fish.enable = true;
}
