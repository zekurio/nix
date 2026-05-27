{
  programs = {
    atuin = {
      enable = true;
      enableFishIntegration = true;
    };

    fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_greeting

        if set -q GHOSTTY_RESOURCES_DIR; and not set -q ZELLIJ
          exec zellij attach --create
        end
      '';
      shellAliases = {
        ls = "eza";
        ll = "eza -lah";
        la = "eza -la";
        lt = "eza --tree";
        codex = "command codex --dangerously-bypass-approvals-and-sandbox";
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
