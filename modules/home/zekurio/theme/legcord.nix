{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.theme) rgb grey mix variants;
  themeName = lib.toLower config.theme.name;

  # DiscordRecolor takes bare "r,g,b" triplets.
  colors = variant: let
    inherit (variant) shade accent base raised surface text dimText bright ansi brightAnsi;
    darker = mix base (grey 0);

    # Chat sits on backgroundprimary. Discord darkens each step after it,
    # down to popouts on backgroundfloating. Its light mode darkens the
    # sidebars toward the text instead and lifts popouts above the chat.
    backgrounds = {
      dark = {
        backgroundsecondary = darker 15;
        backgroundsecondaryalt = darker 25;
        backgroundtertiary = darker 35;
        backgroundfloating = darker 45;
      };
      light = {
        backgroundsecondary = shade 31;
        backgroundsecondaryalt = shade 35;
        backgroundtertiary = shade 40;
        backgroundfloating = mix base (grey 255) 60;
      };
    };
  in
    lib.mapAttrs (_: rgb) ({
        accentcolor = accent;
        accentcolor2 = ansi.magenta;
        linkcolor = ansi.blue;
        mentioncolor = ansi.yellow;
        successcolor = ansi.green;
        warningcolor = ansi.yellow;
        dangercolor = accent;

        textbrightest = bright;
        textbrighter = text;
        textbright = ansi.white;
        textdark = dimText;
        textdarker = brightAnsi.black;
        textdarkest = shade 80;

        backgroundcode = raised;
        backgroundaccent = surface;
        backgroundprimary = base;
      }
      // backgrounds.${variant.appearance});

  declarations = attrs: lib.concatStrings (lib.mapAttrsToList (name: value: "  --${name}: ${value};\n") attrs);

  # DiscordRecolor only swaps Discord's colour variables and keeps its
  # layout. It tracks Discord's variable names across client updates.
  # It feeds the same variables to light and dark mode, so the light
  # palette overrides them while Discord's theme class sits on <html>.
  # The remote @import needs Legcord's CSP setting at its default, "none".
  css = pkgs.writeText "legcord-${themeName}.css" ''
    @import url("https://mwittrien.github.io/BetterDiscordAddons/Themes/DiscordRecolor/DiscordRecolor.css");

    :root {
    ${declarations (colors variants.dark // {settingsicons = "0";})}}

    :root.theme-light {
    ${declarations (colors variants.light)}}
  '';

  manifest = (pkgs.formats.json {}).generate "legcord-${themeName}.json" {
    inherit (config.theme) name;
    author = "zekurio";
    theme = "theme.css";
    enabled = true;
  };

  themesDir =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "${config.home.homeDirectory}/Library/Application Support/legcord/themes"
    else "${config.xdg.configHome}/legcord/themes";
in {
  # Legcord rewrites manifest.json when the theme is toggled, so copy the
  # files instead of linking them read-only with home.file. A rebuild turns
  # the theme back on.
  home.activation.legcordTheme = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run install -Dm644 ${manifest} "${themesDir}/${themeName}/manifest.json"
    run install -Dm644 ${css} "${themesDir}/${themeName}/theme.css"
  '';
}
