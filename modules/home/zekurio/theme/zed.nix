{
  config,
  lib,
  ...
}: let
  inherit (config.theme) hex mix variants;

  # Zed takes #rrggbbaa, so a two-digit suffix on hex sets the opacity.
  transparent = "#00000000";
  paint = color: names: lib.genAttrs names (_: {color = hex color;});

  style = variant: let
    inherit (variant) shade accent base raised surface text dimText bright ansi brightAnsi;
    zedStatus = name: color: {
      ${name} = hex color;
      "${name}.background" = hex color + "1a";
      "${name}.border" = hex (mix base color 35);
    };
  in
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

      border = hex (shade 58);
      "border.variant" = hex (shade 46);
      "border.focused" = hex accent;
      "border.selected" = hex variant.selection;
      "border.transparent" = transparent;
      "border.disabled" = hex (shade 50);

      "element.background" = hex surface;
      "element.hover" = hex (shade 54);
      "element.active" = hex (shade 64);
      "element.selected" = hex (shade 64);
      "element.disabled" = hex surface;
      "ghost_element.background" = transparent;
      "ghost_element.hover" = hex (shade 54);
      "ghost_element.active" = hex (shade 64);
      "ghost_element.selected" = hex (shade 64);
      "ghost_element.disabled" = hex surface;
      "drop_target.background" = hex accent + "40";

      text = hex text;
      "text.muted" = hex dimText;
      "text.placeholder" = hex brightAnsi.black;
      "text.disabled" = hex brightAnsi.black;
      "text.accent" = hex brightAnsi.red;
      "link_text.hover" = hex brightAnsi.red;
      icon = hex text;
      "icon.muted" = hex dimText;
      "icon.disabled" = hex brightAnsi.black;
      "icon.placeholder" = hex dimText;
      "icon.accent" = hex accent;

      "editor.foreground" = hex text;
      "editor.background" = hex base;
      "editor.gutter.background" = hex base;
      "editor.subheader.background" = hex raised;
      "editor.active_line.background" = hex (shade 31);
      "editor.highlighted_line.background" = hex (shade 31);
      "editor.line_number" = hex (shade 88);
      "editor.active_line_number" = hex text;
      "editor.hover_line_number" = hex dimText;
      "editor.invisible" = hex (shade 70);
      "editor.wrap_guide" = hex (shade 31);
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
      "scrollbar.track.border" = hex (shade 31);

      "terminal.background" = hex base;
      "terminal.foreground" = hex text;
      "terminal.bright_foreground" = hex bright;
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
in {
  programs.zed-editor = {
    userSettings.theme = {
      mode = "system";
      light = variants.light.name;
      dark = variants.dark.name;
    };
    themes.${config.theme.name} = {
      "$schema" = "https://zed.dev/schema/themes/v0.2.0.json";
      inherit (config.theme) name;
      author = "zekurio";
      themes = map (variant: {
        inherit (variant) name appearance;
        style = style variant;
      }) [variants.dark variants.light];
    };
  };
}
