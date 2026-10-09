{
  flake.modules.nixos.lilith = {
    lib,
    pkgs,
    ...
  }: let
    # Colours are [r g b] lists so the shades below can be derived from them.
    rgb = lib.concatMapStringsSep "," toString;
    hex = color:
      "#" + lib.concatMapStrings (channel: lib.toLower (lib.fixedWidthString 2 "0" (lib.toHexString channel))) color;
    grey = level: [level level level];
    mix = from: to: percent:
      lib.zipListsWith (a: b: (a * (100 - percent) + b * percent) / 100) from to;

    # The only hue in the Plasma scheme. White text on it keeps a 4.6:1 contrast.
    accent = [214 60 64];

    # Breeze Dark's lightness steps without its blue tint.
    base = grey 22;
    raised = grey 35;
    surface = grey 44;
    text = grey 240;
    dimText = grey 160;
    white = grey 255;

    negative = [218 68 83];
    neutral = [246 116 0];
    positive = [39 174 96];
    visited = mix accent dimText 50;

    colorSet = background: alternate: {
      BackgroundNormal = background;
      BackgroundAlternate = alternate;
      ForegroundNormal = text;
      ForegroundInactive = dimText;
      ForegroundActive = accent;
      ForegroundLink = mix accent white 30;
      ForegroundVisited = visited;
      ForegroundNegative = negative;
      ForegroundNeutral = neutral;
      ForegroundPositive = positive;
      DecorationFocus = accent;
      DecorationHover = accent;
    };

    colors = {
      "Colors:View" = colorSet base (grey 31);
      "Colors:Window" = colorSet raised surface;
      "Colors:Button" = colorSet surface (mix surface accent 30);
      "Colors:Header" = colorSet surface raised;
      # KConfig nests groups as [Colors:Header][Inactive]. Plasma copies the
      # window colours into inactive headers only when this group exists.
      "Colors:Header][Inactive" = colorSet raised surface;
      "Colors:Tooltip" = colorSet surface raised;
      "Colors:Complementary" = colorSet raised (mix raised accent 30);
      "Colors:Selection" =
        colorSet accent (mix accent (grey 0) 25)
        // {
          ForegroundNormal = white;
          ForegroundInactive = mix white accent 30;
          ForegroundActive = white;
          ForegroundLink = [253 188 75];
          # The semantic colours are too dark to read on the accent.
          ForegroundVisited = mix visited white 60;
          ForegroundNegative = mix negative white 60;
          ForegroundNeutral = mix neutral white 60;
          ForegroundPositive = mix positive white 60;
        };
      WM = {
        activeBackground = surface;
        activeBlend = text;
        activeForeground = text;
        inactiveBackground = raised;
        inactiveBlend = dimText;
        inactiveForeground = dimText;
      };
    };

    # Terminal output and syntax highlighting need more hues to tell things
    # apart, so these share one lightness and a low chroma to stay quieter than
    # the red.
    ansiNames = ["black" "red" "green" "yellow" "blue" "magenta" "cyan" "white"];
    ansi = {
      black = surface;
      red = mix accent white 15;
      green = [134 185 144];
      yellow = [194 167 111];
      blue = [137 174 221];
      magenta = [194 155 203];
      cyan = [105 186 191];
      white = grey 200;
    };
    brightAnsi = {
      black = grey 120;
      red = mix accent white 30;
      green = [162 215 172];
      yellow = [223 196 139];
      blue = [165 202 251];
      magenta = [223 183 232];
      cyan = [134 215 220];
      inherit white;
    };

    # Zed takes #rrggbbaa, so a two-digit suffix on hex sets the opacity.
    transparent = "#00000000";
    zedStatus = name: color: {
      ${name} = hex color;
      "${name}.background" = hex color + "1a";
      "${name}.border" = hex (mix base color 35);
    };
    paint = color: names: lib.genAttrs names (_: {color = hex color;});
    zedStyle =
      {
        background = hex surface;
        "surface.background" = hex raised;
        "elevated_surface.background" = hex raised;
        "panel.background" = hex raised;
        "status_bar.background" = hex surface;
        "title_bar.background" = hex surface;
        "title_bar.inactive_background" = hex raised;
        "toolbar.background" = hex base;
        "tab_bar.background" = hex raised;
        "tab.inactive_background" = hex raised;
        "tab.active_background" = hex base;

        border = hex (grey 58);
        "border.variant" = hex (grey 46);
        "border.focused" = hex accent;
        "border.selected" = hex (mix base accent 50);
        "border.transparent" = transparent;
        "border.disabled" = hex (grey 50);

        "element.background" = hex surface;
        "element.hover" = hex (grey 54);
        "element.active" = hex (grey 64);
        "element.selected" = hex (grey 64);
        "element.disabled" = hex surface;
        "ghost_element.background" = transparent;
        "ghost_element.hover" = hex (grey 54);
        "ghost_element.active" = hex (grey 64);
        "ghost_element.selected" = hex (grey 64);
        "ghost_element.disabled" = hex surface;
        "drop_target.background" = hex accent + "40";

        text = hex text;
        "text.muted" = hex dimText;
        "text.placeholder" = hex (grey 120);
        "text.disabled" = hex (grey 120);
        "text.accent" = hex brightAnsi.red;
        "link_text.hover" = hex brightAnsi.red;
        icon = hex text;
        "icon.muted" = hex dimText;
        "icon.disabled" = hex (grey 120);
        "icon.placeholder" = hex dimText;
        "icon.accent" = hex accent;

        "editor.foreground" = hex text;
        "editor.background" = hex base;
        "editor.gutter.background" = hex base;
        "editor.subheader.background" = hex raised;
        "editor.active_line.background" = hex (grey 31);
        "editor.highlighted_line.background" = hex (grey 31);
        "editor.line_number" = hex (grey 88);
        "editor.active_line_number" = hex text;
        "editor.hover_line_number" = hex dimText;
        "editor.invisible" = hex (grey 70);
        "editor.wrap_guide" = hex (grey 31);
        "editor.active_wrap_guide" = hex surface;
        # Red here would read as an error under every use of a symbol.
        "editor.document_highlight.read_background" = hex dimText + "26";
        "editor.document_highlight.write_background" = hex dimText + "40";
        "search.match_background" = hex ansi.yellow + "55";
        "search.active_match_background" = hex accent + "66";

        "scrollbar.thumb.background" = hex dimText + "4c";
        "scrollbar.thumb.hover_background" = hex dimText + "80";
        "scrollbar.thumb.border" = transparent;
        "scrollbar.track.background" = transparent;
        "scrollbar.track.border" = hex (grey 31);

        "terminal.background" = hex base;
        "terminal.foreground" = hex text;
        "terminal.bright_foreground" = hex white;
        "terminal.dim_foreground" = hex dimText;

        "version_control.added" = hex ansi.green;
        "version_control.modified" = hex ansi.yellow;
        "version_control.deleted" = hex ansi.red;
        "version_control.word_added" = hex ansi.green + "59";
        "version_control.word_deleted" = hex ansi.red + "66";
        "version_control.conflict_marker.ours" = hex ansi.green + "1a";
        "version_control.conflict_marker.theirs" = hex ansi.blue + "1a";

        # The first player is the local cursor and selection.
        players =
          map (color: {
            cursor = hex color;
            background = hex color;
            selection = hex color + "4d";
          }) [
            accent
            ansi.blue
            ansi.green
            ansi.magenta
            ansi.yellow
            ansi.cyan
            brightAnsi.blue
            brightAnsi.green
          ];

        syntax =
          lib.recursiveUpdate (
            paint ansi.red ["keyword" "preproc" "title" "punctuation.list_marker" "punctuation.markup" "punctuation.special" "diff.minus"]
            // paint ansi.blue ["function" "constructor" "tag" "label" "variant" "selector.pseudo" "link_text"]
            // paint ansi.green ["string" "text.literal" "diff.plus"]
            // paint ansi.yellow ["number" "boolean" "constant" "selector" "string.regex" "string.special" "string.special.symbol" "variable.special"]
            // paint ansi.cyan ["type" "enum" "link_uri"]
            // paint ansi.magenta ["property" "attribute"]
            // paint text ["variable" "variable.parameter" "namespace" "embedded" "primary" "emphasis" "emphasis.strong"]
            // paint ansi.white ["operator" "punctuation" "punctuation.bracket" "punctuation.delimiter"]
            // paint dimText ["string.escape" "comment.doc"]
            // paint brightAnsi.black ["comment" "hint" "predictive"]
          ) {
            emphasis.font_style = "italic";
            "emphasis.strong".font_weight = 700;
            link_text.font_style = "italic";
            predictive.font_style = "italic";
          };
      }
      // lib.concatMapAttrs zedStatus {
        conflict = ansi.yellow;
        created = ansi.green;
        deleted = ansi.red;
        error = ansi.red;
        hidden = brightAnsi.black;
        hint = brightAnsi.black;
        ignored = brightAnsi.black;
        info = ansi.blue;
        modified = ansi.yellow;
        predictive = brightAnsi.black;
        renamed = ansi.blue;
        success = ansi.green;
        unreachable = dimText;
        warning = ansi.yellow;
      }
      // lib.concatMapAttrs (name: color: {
        "terminal.ansi.${name}" = hex color;
        "terminal.ansi.bright_${name}" = hex brightAnsi.${name};
        "terminal.ansi.dim_${name}" = hex (mix color base 35);
      })
      ansi;

    colorScheme = "Lilith";
    colorSchemePackage = pkgs.writeTextDir "share/color-schemes/${colorScheme}.colors" (
      # toINI would escape the brackets of the nested header group.
      lib.generators.toINI {mkSectionName = lib.id;} (
        lib.mapAttrs (_: lib.mapAttrs (_: rgb)) colors
        // {
          General = {
            ColorScheme = colorScheme;
            Name = colorScheme;
            shadeSortColumn = true;
          };
          KDE.contrast = 4;
          "ColorEffects:Disabled" = {
            Color = rgb (grey 56);
            ColorAmount = 0;
            ColorEffect = 0;
            ContrastAmount = 0.65;
            ContrastEffect = 1;
            IntensityAmount = 0.1;
            IntensityEffect = 2;
          };
          "ColorEffects:Inactive" = {
            ChangeSelectionColor = true;
            Color = rgb (grey 112);
            ColorAmount = 0.025;
            ColorEffect = 2;
            ContrastAmount = 0.1;
            ContrastEffect = 2;
            Enable = false;
            IntensityAmount = 0;
            IntensityEffect = 0;
          };
        }
      )
    );
  in {
    environment.systemPackages = [
      colorSchemePackage
      pkgs.klassy
      # Papirus ships blue folders; red is its folder colour nearest the accent.
      (pkgs.papirus-icon-theme.override {color = "red";})
    ];

    home-manager.users.zekurio.programs = {
      # Plasma re-applies the scheme at login whenever this file's hash changes,
      # so palette edits need a new session, not a new scheme name.
      plasma = {
        workspace = {
          inherit colorScheme;
          iconTheme = "Papirus-Dark";
          windowDecorations = {
            library = "org.kde.klassy";
            theme = "Klassy";
          };
        };
        # A stored accent replaces the scheme's own, and Plasma keeps rewriting
        # it from the wallpaper while that option is on.
        configFile.kdeglobals.General = {
          AccentColor = null;
          accentColorFromWallpaper = false;
        };
      };

      ghostty = {
        settings.theme = colorScheme;
        themes.${colorScheme} = {
          background = hex base;
          foreground = hex text;
          cursor-color = hex accent;
          cursor-text = hex white;
          # The full accent is too loud across whole selected lines.
          selection-background = hex (mix base accent 50);
          selection-foreground = hex white;
          palette = lib.imap0 (index: color: "${toString index}=${hex color}") (
            map (name: ansi.${name}) ansiNames ++ map (name: brightAnsi.${name}) ansiNames
          );
        };
      };

      zed-editor = {
        userSettings.theme = colorScheme;
        themes.${colorScheme} = {
          "$schema" = "https://zed.dev/schema/themes/v0.2.0.json";
          name = colorScheme;
          author = "zekurio";
          themes = [
            {
              name = colorScheme;
              appearance = "dark";
              style = zedStyle;
            }
          ];
        };
      };
    };
  };
}
