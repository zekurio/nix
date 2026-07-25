{
  flake.modules.homeManager.zekurio = {
    lib,
    pkgs,
    ...
  }: let
    isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  in {
    config = {
      programs.ghostty = {
        enable = true;
        package = null;
        enableFishIntegration = true;
        systemd.enable = false;
        settings =
          {
            window-width = 150;
            window-height = 38;
            window-save-state = "never";
            background-blur = true;
            background-opacity = 0.96;
            font-family = "FiraCode Nerd Font Mono";
            font-size = 14;
            term = "xterm-256color";
            window-inherit-font-size = false;
          }
          // lib.optionalAttrs isDarwin {
            macos-titlebar-style = "transparent";
          };
      };

      catppuccin.ghostty.enable = true;
    };
  };
}
