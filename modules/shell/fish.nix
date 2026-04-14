{
  lib,
  config,
  ...
}: let
  cfg = config.modules.shell;
in {
  config = lib.mkIf cfg.enable {
    home-manager.users.zekurio.programs = {
      atuin = {
        enable = true;
        enableFishIntegration = true;
      };

      direnv = {
        enable = true;
        enableFishIntegration = true;
        nix-direnv.enable = true;
      };

      fish = {
        enable = true;
        interactiveShellInit = ''
          set fish_greeting
        '';
        shellAliases = {
          ls = "eza";
          ll = "eza -lah";
          la = "eza -la";
          lt = "eza --tree";
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
  };
}
