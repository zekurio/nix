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
    # themed. Appearance-aware CLI ports are managed by appearance/default.nix.
    catppuccin =
      {
        enable = true;
        autoEnable = false;
      }
      // import ../../../_palette.nix;
  };
}
