{
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    programs.ghostty = {
      enable = true;
      package = null;
      enableFishIntegration = true;
      settings = {
        window-width = 150;
        window-height = 38;
        window-save-state = "never";
        background-blur = true;
        background-opacity = 0.96;
        font-size = 14;
        macos-titlebar-style = "transparent";
      };
    };
  };
}
