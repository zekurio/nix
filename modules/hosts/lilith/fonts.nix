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

    # The greeter runs before any user session and reads no Plasma settings.
    services.displayManager.sddm.settings.Theme.Font = "${sans},10";

    home-manager.users.zekurio = {
      # The shared profile disables user fontconfig on macOS and headless hosts;
      # Steam reads the user's fontconfig configuration on this desktop.
      fonts.fontconfig.enable = lib.mkForce true;

      # Plasma names its fonts in kdeglobals instead of asking fontconfig for
      # the defaults above, and syncs these to GTK applications at login.
      programs.plasma.fonts = let
        ui = pointSize: {
          family = sans;
          inherit pointSize;
        };
      in {
        general = ui 10;
        small = ui 8;
        toolbar = ui 10;
        menu = ui 10;
        windowTitle = ui 10;
        fixedWidth = {
          family = mono;
          pointSize = 10;
        };
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
