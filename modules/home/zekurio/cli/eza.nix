{
  flake.modules.homeManager.zekurio = {...}: {
    programs.eza = {
      enable = true;
      icons = "always";
      colors = "always";
      # Aliases are hand-maintained in fish.nix; don't let eza inject its own.
      enableFishIntegration = false;
    };

    catppuccin.eza.enable = true;
  };
}
