{
  flake.modules.homeManager.zekurio = {
    config,
    lib,
    ...
  }: let
    inherit (config.theme) rgb grey mix accent base raised surface text dimText white ansi;
    themeName = lib.toLower config.theme.name;
    darker = mix base (grey 0);

    # DiscordRecolor takes bare "r,g,b" triplets.
    colors = lib.mapAttrs (_: rgb) {
      accentcolor = accent;
      accentcolor2 = ansi.magenta;
      linkcolor = ansi.blue;
      mentioncolor = ansi.yellow;
      successcolor = ansi.green;
      warningcolor = ansi.yellow;
      dangercolor = accent;

      textbrightest = white;
      textbrighter = text;
      textbright = ansi.white;
      textdark = dimText;
      textdarker = grey 120;
      textdarkest = grey 80;

      # Chat sits on backgroundprimary. Discord darkens each step after it,
      # down to popouts on backgroundfloating.
      backgroundcode = raised;
      backgroundaccent = surface;
      backgroundprimary = base;
      backgroundsecondary = darker 15;
      backgroundsecondaryalt = darker 25;
      backgroundtertiary = darker 35;
      backgroundfloating = darker 45;
    };

    declarations = attrs: lib.concatStrings (lib.mapAttrsToList (name: value: "  --${name}: ${value};\n") attrs);
  in {
    programs.vesktop.vencord = {
      # DiscordRecolor only swaps Discord's colour variables and keeps its
      # layout. It tracks Discord's variable names across client updates.
      themes.${themeName} = ''
        @import url("https://mwittrien.github.io/BetterDiscordAddons/Themes/DiscordRecolor/DiscordRecolor.css");

        :root {
        ${declarations (colors // {settingsicons = "0";})}}
      '';
      # Vencord rewrites its settings file at runtime, so merge into it.
      mutableSettings = true;
      settings.enabledThemes = ["${themeName}.css"];
    };
  };
}
