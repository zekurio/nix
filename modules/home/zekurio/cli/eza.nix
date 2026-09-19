{
  flake.modules.homeManager.zekurio = {config, ...}: {
    programs.eza = {
      enable = true;
      icons = "always";
      colors = "always";
      # Aliases are hand-maintained in fish.nix; don't let eza inject its own.
      enableFishIntegration = false;
    };

    # Fish points eza at one of these directories for each shell session.
    catppuccin.eza.enable = false;
    xdg.configFile = let
      theme = flavor: {
        source = "${config.catppuccin.sources.eza}/${flavor}/catppuccin-${flavor}-${config.catppuccin.accent}.yml";
      };
    in {
      "eza/frappe/theme.yml" = theme "frappe";
      "eza/latte/theme.yml" = theme "latte";
    };
  };
}
