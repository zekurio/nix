{
  flake.modules.homeManager.zekurio = {...}: {
    programs = {
      atuin = {
        enable = true;
        enableZshIntegration = true;
      };

      zsh = {
        enable = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
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
        enableZshIntegration = true;
      };

      zoxide = {
        enable = true;
        enableZshIntegration = true;
        options = [
          "--cmd"
          "cd"
        ];
      };
    };

    # Highlighting colors come from the fixed global Catppuccin flavor.
    catppuccin.zsh-syntax-highlighting.enable = true;
  };
}
