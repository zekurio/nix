{
  flake.modules.homeManager.zekurio = {
    config,
    inputs,
    ...
  }: {
    imports = [
      inputs.catppuccin.homeModules.catppuccin
    ];

    programs = {
      bat = {
        enable = true;
        config.theme = "Catppuccin Frappe";
        themes = {
          "Catppuccin Frappe" = {
            src = config.catppuccin.sources.bat;
            file = "Catppuccin Frappe.tmTheme";
          };
          "Catppuccin Latte" = {
            src = config.catppuccin.sources.bat;
            file = "Catppuccin Latte.tmTheme";
          };
        };
      };
      btop.enable = true;
    };

    # autoEnable is off so each program opts in or installs both themes.
    # Starship keeps its palettes in prompt.nix because it has no port.
    catppuccin = {
      enable = true;
      autoEnable = false;
      bat.enable = false;
      flavor = "frappe";
      accent = "blue";
    };
  };
}
