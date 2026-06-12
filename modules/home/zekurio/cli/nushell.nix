{
  programs = {
    atuin = {
      enable = true;
      enableNushellIntegration = true;
    };

    nushell = {
      enable = true;
      settings = {
        show_banner = false;
      };
      shellAliases = {
        ls = "eza";
        ll = "eza -lah";
        la = "eza -la";
        lt = "eza --tree";
        cat = "bat";
        codex = "^codex --dangerously-bypass-approvals-and-sandbox";
        claude = "^claude --dangerously-skip-permissions";
      };
    };

    carapace = {
      enable = true;
      enableNushellIntegration = true;
    };

    zoxide = {
      enable = true;
      enableNushellIntegration = true;
      options = [
        "--cmd"
        "cd"
      ];
    };
  };
}
