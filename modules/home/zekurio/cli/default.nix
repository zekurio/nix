{
  flake.modules.homeManager.zekurio = {inputs, ...}: {
    imports = [
      inputs.catppuccin.homeModules.catppuccin
    ];

    programs = {
      bat.enable = true;
      btop.enable = true;
    };

    # autoEnable is off so only the ports enabled next to each program are
    # themed; flavor and accent cascade to every port. Starship keeps its own
    # literal palette in prompt.nix because it is not a catppuccin port.
    catppuccin = {
      enable = true;
      autoEnable = false;
      bat.enable = true;
      flavor = "frappe";
      accent = "blue";
    };
  };
}
