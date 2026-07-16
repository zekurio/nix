{
  flake.modules.homeManager.zekurio = {...}: {
    programs.eza = {
      enable = true;
      # Aliases are hand-maintained in fish.nix; don't let eza inject its own.
      enableFishIntegration = false;
    };
  };
}
