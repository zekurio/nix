{
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

    # Zed bundles its own fonts and ignores fontconfig's defaults. Its
    # terminal follows the buffer font.
    programs.zed-editor.userSettings = {
      ui_font_family = sans;
      buffer_font_family = mono;
    };
  };
}
