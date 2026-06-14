{
  config,
  lib,
  ...
}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    initContent = lib.mkOrder 1250 ''
      source '${config.catppuccin.sources.zsh-syntax-highlighting}/catppuccin_frappe-zsh-syntax-highlighting.zsh'
    '';

    shellAliases = {
      ls = "eza";
      ll = "eza -lah";
      la = "eza -la";
      lt = "eza --tree";
      cat = "bat";
      datawork = "nu";
      codex = "codex --dangerously-bypass-approvals-and-sandbox";
      claude = "claude --dangerously-skip-permissions";
    };
  };
}
