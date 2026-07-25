{
  flake.modules.homeManager.zekurio = {...}: {
    programs.eza = {
      enable = true;
      # Aliases are hand-maintained in zsh.nix; don't let eza inject its own.
      enableZshIntegration = false;
    };

    catppuccin.eza.enable = true;
  };
}
