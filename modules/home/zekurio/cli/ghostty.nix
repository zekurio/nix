{
  flake.modules.homeManager.zekurio = {
    config,
    lib,
    pkgs,
    ...
  }: {
    config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      programs.ghostty = {
        enable = true;
        package = null;
        enableFishIntegration = true;
        systemd.enable = false;
        settings = {
          window-width = 150;
          window-height = 38;
          window-save-state = "never";
          window-padding-x = 10;
          window-padding-y = 8;
          background-blur = true;
          background-opacity = 0.96;
          font-family = "FiraCode Nerd Font";
          font-size = 14;
          term = "xterm-256color";
          window-inherit-font-size = false;
          macos-titlebar-style = "transparent";
          theme = "light:catppuccin-latte,dark:catppuccin-frappe";
        };
      };

      xdg.configFile = {
        "ghostty/themes/catppuccin-latte".source = "${config.catppuccin.sources.ghostty}/catppuccin-latte.conf";
        "ghostty/themes/catppuccin-frappe".source = "${config.catppuccin.sources.ghostty}/catppuccin-frappe.conf";
      };
    };
  };
}
