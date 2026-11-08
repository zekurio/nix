{
  home-manager.users.zekurio = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (config.dux.colors) variants;

    colors = variant: let
      inherit (variant) filledAccent accent2 base raised surface sidebar panel frame floating text dimText faintText border error ansi;
    in
      lib.mapAttrs (_: color: color.rgb) {
        # Discord's buttons always print white labels on this.
        accentcolor = filledAccent;
        accentcolor2 = accent2;
        linkcolor = ansi.blue;
        mentioncolor = ansi.yellow;
        successcolor = ansi.green;
        warningcolor = ansi.yellow;
        dangercolor = error;

        textbrightest = text;
        textbrighter = text;
        textbright = dimText;
        textdark = dimText;
        textdarker = faintText;
        textdarkest = border;

        backgroundcode = raised;
        backgroundaccent = surface;
        backgroundprimary = base;
        backgroundsecondary = sidebar;
        backgroundsecondaryalt = panel;
        backgroundtertiary = frame;
        backgroundfloating = floating;
      };

    # The "default" window style puts Legcord's buttons over the right end of
    # Discord's top bar, and Discord drops that bar's end padding on Linux.
    # Legcord 1.3.1 reserves the space with a title + trailing sibling
    # selector that current Discord no longer matches (Legcord#1180), so the
    # inbox and help icons sit under the buttons. Pad the bar by the width of
    # #window-controls-container from linuxTitlebar.css, and clear Legcord's
    # margin in case its selector matches again.
    titlebarFix =
      lib.warnIf (pkgs.legcord.version != "1.3.1")
      "Legcord is past 1.3.1. If Legcord#1180 is fixed, delete titlebarFix in modules/hosts/lilith/dux-theme/legcord.nix."
      ''
        [legcord-platform="linux"] :is([class^="bar_"], [class*=" bar_"]):has(> [class^="trailing_"]) {
          padding-inline-end: 142px;
        }

        [legcord-platform="linux"] :is([class^="bar_"], [class*=" bar_"]) > div[class*="title"] + div[class*="trailing"] {
          margin-right: 0 !important;
        }
      '';

    declarations = attrs: lib.concatStrings (lib.mapAttrsToList (name: value: "  --${name}: ${value};\n") attrs);

    # DiscordRecolor only swaps Discord's colour variables and keeps its
    # layout. It tracks Discord's variable names across client updates.
    # It feeds the same variables to light and dark mode, so the light
    # palette overrides them while Discord's theme class sits on <html>.
    # The remote @import needs Legcord's CSP setting at its default, "none".
    template = pkgs.writeText "legcord-dux.css" ''
      @import url("https://mwittrien.github.io/BetterDiscordAddons/Themes/DiscordRecolor/DiscordRecolor.css");

      :root {
      ${declarations (colors variants.dark // {settingsicons = "0";})}}

      :root.theme-light {
      ${declarations (colors variants.light)}}

      ${titlebarFix}
    '';
  in {
    # Legcord reads theme folders once at startup, but it watches its Quick
    # CSS file and reapplies it on every change. matugen rewrites the file
    # in place, which is the change event Legcord waits for, so the colours
    # follow Dux without a restart. Edits in Legcord's Quick CSS editor are
    # overwritten on the next Dux theme change.
    dux.templates.legcord = {
      source = template;
      target = "${config.xdg.configHome}/legcord/quickCss.css";
    };
  };
}
