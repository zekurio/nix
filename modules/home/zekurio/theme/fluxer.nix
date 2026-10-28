{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.theme) hex rgb grey mix white name variants;
  themesDir = "${config.xdg.configHome}/fluxer/themes";

  alpha = color: percent: "rgba(${rgb color}, ${toString percent}%)";

  # Fluxer tints its greys violet. Overriding these roles is enough, because
  # its remaining colours, such as code blocks and tints, mix them in CSS.
  colors = variant: let
    inherit (variant) shade accent base raised surface text dimText bright ansi brightAnsi;
    roles = lib.mapAttrs (_: hex) (
      {
        "background-primary" = base;
        "bg-primary" = base;
        "bg-table-row-odd" = base;
        "background-secondary" = shade 31;
        "bg-secondary" = shade 31;
        "bg-table-row-even" = shade 31;
        "guild-badge-surface" = shade 31;
        "background-secondary-lighter" = raised;
        "composer-surface-color" = raised;
        "background-secondary-alt" = shade 38;
        "background-textarea" = shade 38;
        "bg-blockquote" = shade 38;
        "background-channel-header" = shade 40;
        "guild-list-foreground" = shade 42;
        "guilds-layout-item-bg" = shade 42;
        "background-tertiary" = surface;
        "bg-tertiary" = surface;
        "bg-table-header" = surface;
        "form-surface-background" = surface;
        "background-header-primary" = shade 46;
        "background-header-secondary" = shade 46;
        "background-header-primary-hover" = shade 54;
        "control-button-hover-bg" = shade 50;
        "control-button-active-bg" = shade 58;

        "text-primary" = text;
        "text-chat" = text;
        "surface-interactive-selected-color" = text;
        "control-button-hover-text" = text;
        "control-button-active-text" = text;
        "text-secondary" = ansi.white;
        "code-text" = ansi.white;
        "text-code" = ansi.white;
        "text-primary-muted" = dimText;
        "text-chat-muted" = dimText;
        "text-tertiary" = dimText;
        "message-timestamp-color" = dimText;
        "control-button-normal-text" = dimText;
        "text-tertiary-muted" = mix dimText brightAnsi.black 50;
        "text-tertiary-secondary" = brightAnsi.black;
        "text-link" = ansi.blue;
        "text-warning" = ansi.yellow;

        "brand-primary" = accent;
        "accent-primary" = accent;
        "focus-primary" = accent;
        "brand-secondary" = mix accent (grey 0) 15;
        "brand-primary-light" = mix accent white 50;
        "brand-primary-foreground" = brightAnsi.red;
        "button-primary-fill" = accent;
        "button-primary-active-fill" = mix accent (grey 0) 15;
        "button-primary-text" = white;

        "accent-danger" = ansi.red;
        "accent-info" = ansi.blue;
        "accent-purple" = ansi.magenta;
        "accent-success" = ansi.green;
        "accent-warning" = ansi.yellow;
        "status-online" = ansi.green;
        "status-idle" = ansi.yellow;
        "status-warning" = ansi.yellow;
        "status-dnd" = ansi.red;
        "status-danger" = ansi.red;
        "status-offline" = brightAnsi.black;
      }
      # Fluxer's light mode prints ANSI black in the text colour, where the
      # palette's black sits near the canvas, so keep its black and white.
      // lib.concatMapAttrs (name: color: {
        "ansi-fg-${name}" = color;
        "ansi-bg-${name}" = color;
        "ansi-fg-bright-${name}" = brightAnsi.${name};
        "ansi-bg-bright-${name}" = brightAnsi.${name};
      })
      (removeAttrs ansi ["black" "white"])
    );
  in
    roles
    // {
      "background-modifier-hover" = alpha bright 5;
      "bg-hover" = alpha bright 5;
      "surface-interactive-hover-bg" = alpha bright 5;
      "background-modifier-selected" = alpha bright 10;
      "bg-active" = alpha bright 10;
      "surface-interactive-selected-bg" = alpha bright 10;
      "background-modifier-accent" = alpha dimText 15;
      "background-modifier-accent-focus" = alpha dimText 22;
      "border-color" = alpha dimText 20;
      "border-color-hover" = alpha dimText 30;
      "border-color-focus" = alpha accent 45;
      "floating-surface-ring-color" = alpha dimText 15;
      "floating-surface-ring-color-strong" = alpha dimText 25;
      "panel-control-border" = alpha dimText 35;
      "panel-control-divider" = alpha dimText 25;
      "user-area-divider-color" = alpha dimText 20;
      "text-selection" = alpha accent 35;
    };

  declarations = variant: lib.concatStrings (lib.mapAttrsToList (name: value: "  --${name}: ${value};\n") (colors variant));

  # Fluxer sets its dark colours on :root and the light ones on .theme-light,
  # and puts the active theme's class on <html>. Matching both :root and the
  # class outranks either rule.
  themeFile = pkgs.writeText "fluxer-${lib.toLower name}.css" ''
    /**
     * @name ${name}
     * @author zekurio
     */

    :root:not(.theme-light) {
    ${declarations variants.dark}}

    :root.theme-light {
    ${declarations variants.light}}
  '';
in {
  # Fluxer skips symlinks in a theme folder, so copy the file instead of
  # linking it with home.file. Add the folder once under Settings > Themes
  # and turn the theme on; Fluxer reloads it on every change after that.
  home.activation.fluxerTheme = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run install -Dm644 ${themeFile} "${themesDir}/${lib.toLower name}.css"
  '';
}
