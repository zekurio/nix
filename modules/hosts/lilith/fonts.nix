{
  flake.modules.nixos.lilith = {
    lib,
    pkgs,
    ...
  }: let
    sans = "Fira Sans";
    mono = "FiraCode Nerd Font Mono";
  in {
    fonts = {
      packages = with pkgs; [
        fira
        nerd-fonts.fira-code
        roboto-slab
      ];
      fontconfig.defaultFonts = {
        sansSerif = [sans];
        serif = ["Roboto Slab"];
        monospace = [mono];
      };
    };

    home-manager.users.zekurio = {
      # The shared profile disables user fontconfig on macOS and headless hosts;
      # Steam reads the user's fontconfig configuration on this desktop.
      fonts.fontconfig.enable = lib.mkForce true;

      # COSMIC names its fonts in its toolkit config instead of asking
      # fontconfig for the defaults above.
      wayland.desktopManager.cosmic.appearance.toolkit = let
        font = family: {
          inherit family;
          stretch = {
            __type = "enum";
            variant = "Normal";
          };
          style = {
            __type = "enum";
            variant = "Normal";
          };
          weight = {
            __type = "enum";
            variant = "Normal";
          };
        };
      in {
        interface_font = font sans;
        monospace_font = font mono;
      };

      # Zed bundles its own fonts and ignores both of the above. Its terminal
      # follows the buffer font.
      programs.zed-editor.userSettings = {
        ui_font_family = sans;
        buffer_font_family = mono;
      };
    };
  };
}
