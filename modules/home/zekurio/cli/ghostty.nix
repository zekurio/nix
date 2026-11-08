{
  lib,
  pkgs,
  ...
}: {
  programs.ghostty = {
    enable = lib.mkDefault pkgs.stdenv.hostPlatform.isDarwin;
    # macOS installs Ghostty from Homebrew.
    package =
      if pkgs.stdenv.hostPlatform.isDarwin
      then null
      else pkgs.ghostty;
    systemd.enable = false;
    settings =
      {
        window-width = 150;
        window-height = 38;
        window-save-state = "never";
        window-padding-x = 10;
        window-padding-y = 8;
        background-blur = true;
        background-opacity = 0.96;
        font-family = "FiraCode Nerd Font";
        # Linux lays out points at 96 DPI and macOS at 72, so the same
        # glyph height needs 4/3 the point size on Darwin.
        font-size =
          if pkgs.stdenv.hostPlatform.isDarwin
          then 16
          else 12;
        term = "xterm-256color";
        window-inherit-font-size = false;
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        macos-titlebar-style = "transparent";
      };
  };
}
