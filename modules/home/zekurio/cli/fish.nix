{
  flake.modules.homeManager.zekurio = {...}: {
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
        shellAliases = {
          ls = "eza";
          ll = "eza -lah";
          la = "eza -la";
          lt = "eza --tree";
          cat = "bat";
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
  };
}
