{
  flake.modules.homeManager.zekurio = {
    config,
    lib,
    pkgs,
    ...
  }: let
    isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
    # Discord comes from Homebrew. Vencord is installed with its upstream installer.
    configDirectory = "Library/Application Support/Vencord";
    themeFile = "catppuccin-${config.catppuccin.flavor}-${config.catppuccin.accent}.theme.css";
  in {
    home.file = lib.mkIf isDarwin {
      "${configDirectory}/settings/settings.json".text = builtins.toJSON {
        enabledThemes = [themeFile];
      };
      "${configDirectory}/themes/${themeFile}".text = ''
        /**
         * @name Catppuccin ${lib.toSentenceCase config.catppuccin.flavor} (${lib.toSentenceCase config.catppuccin.accent})
         * @author Catppuccin
         * @description Soothing pastel theme for Discord
         * @website https://github.com/catppuccin/discord
        **/
        @import url("https://catppuccin.github.io/discord/dist/${themeFile}");
      '';
    };
  };
}
