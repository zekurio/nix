{
  flake.modules.homeManager.zekurio = {...}: {
    programs.eza = {
      enable = true;
      icons = "always";
      colors = "always";
      # Aliases are hand-maintained in zsh.nix; don't let eza inject its own.
      enableZshIntegration = false;
    };

    catppuccin.eza.enable = true;
  };
}
