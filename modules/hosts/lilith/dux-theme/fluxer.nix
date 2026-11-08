{
  home-manager.users.zekurio = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (config.dux.colors) alpha variants;

    # matugen cannot mix colours, but Fluxer's Chromium can.
    mix = from: to: percent: "color-mix(in srgb, ${from}, ${to} ${toString percent}%)";

    # Fluxer tints its greys violet. Overriding these roles is enough, because
    # its remaining colours, such as code blocks and tints, mix them in CSS.
    # Its names differ from Discord's: secondary-lighter is the chat, header
    # and member list, secondary the guild rail and channel list, and primary
    # the window frame. Map them onto Discord's layers so it matches Legcord.
    colors = variant: let
      inherit (variant) accent accent2 onAccent base raised surface strong sidebar frame text dimText faintText border ansi terminalAnsi terminalBrightAnsi;
      roles = lib.mapAttrs (_: color: color.hex) (
        {
          "background-primary" = frame;
          "bg-primary" = frame;
          "bg-table-row-odd" = base;
          "background-secondary" = sidebar;
          "bg-secondary" = sidebar;
          "guild-badge-surface" = sidebar;
          "bg-table-row-even" = raised;
          "background-secondary-lighter" = base;
          "composer-surface-color" = base;
          # Discord's floating user panel sits a step above the channel list.
          "panel-control-bg" = base;
          # Code blocks mix this with tertiary, which lands near Discord's
          # code background, raised.
          "background-secondary-alt" = raised;
          "bg-blockquote" = raised;
          "background-textarea" = raised;
          "background-channel-header" = raised;
          "guild-list-foreground" = surface;
          "guilds-layout-item-bg" = surface;
          "background-tertiary" = surface;
          "bg-tertiary" = surface;
          "bg-table-header" = surface;
          "form-surface-background" = surface;
          "background-header-primary" = surface;
          "background-header-secondary" = surface;
          "background-header-primary-hover" = strong;
          "control-button-hover-bg" = strong;
          "control-button-active-bg" = strong;

          "text-primary" = text;
          "text-chat" = text;
          "surface-interactive-selected-color" = text;
          "control-button-hover-text" = text;
          "control-button-active-text" = text;
          "text-secondary" = dimText;
          "code-text" = dimText;
          "text-code" = dimText;
          "text-primary-muted" = dimText;
          "text-chat-muted" = dimText;
          "text-tertiary" = dimText;
          "message-timestamp-color" = dimText;
          "control-button-normal-text" = dimText;
          "text-tertiary-muted" = faintText;
          "text-tertiary-secondary" = border;
          "text-link" = ansi.blue;
          "text-warning" = ansi.yellow;

          "brand-primary" = accent;
          "accent-primary" = accent;
          "focus-primary" = accent;
          "button-primary-fill" = accent;
          "button-primary-text" = onAccent;

          "accent-danger" = ansi.red;
          "accent-info" = ansi.blue;
          "accent-purple" = accent2;
          "accent-success" = ansi.green;
          "accent-warning" = ansi.yellow;
          "status-online" = ansi.green;
          "status-idle" = ansi.yellow;
          "status-warning" = ansi.yellow;
          "status-dnd" = ansi.red;
          "status-danger" = ansi.red;
          "status-offline" = faintText;
        }
        # Fluxer's light mode prints ANSI black in the text colour, where
        # dank16's black sits near the canvas, so keep its black and white.
        # The ANSI roles colour terminal output, so they follow kitty.
        // lib.concatMapAttrs (name: color: {
          "ansi-fg-${name}" = color;
          "ansi-bg-${name}" = color;
          "ansi-fg-bright-${name}" = terminalBrightAnsi.${name};
          "ansi-bg-bright-${name}" = terminalBrightAnsi.${name};
        })
        (removeAttrs terminalAnsi ["black" "white"])
      );
    in
      roles
      // {
        "brand-secondary" = mix accent.hex "black" 15;
        "brand-primary-light" = mix accent.hex "white" 50;
        "brand-primary-foreground" = mix accent.hex text.hex 30;
        "button-primary-active-fill" = mix accent.hex "black" 15;

        # DiscordRecolor's hover and selection tints, so list rows light up
        # the same amount in both clients.
        "background-modifier-hover" = alpha surface 30;
        "bg-hover" = alpha surface 30;
        "surface-interactive-hover-bg" = alpha surface 30;
        "background-modifier-selected" = alpha surface 60;
        "bg-active" = alpha surface 60;
        "surface-interactive-selected-bg" = alpha surface 60;
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
  in {
    # Fluxer sets its dark colours on :root and the light ones on .theme-light,
    # and puts the active theme's class on <html>. Matching both :root and the
    # class outranks either rule. Fluxer skips symlinks in a theme folder,
    # which matugen's regular file avoids. Add the folder once under
    # Settings > Themes and turn the theme on; Fluxer reloads it on every
    # change after that.
    dux.templates.fluxer = {
      source = pkgs.writeText "fluxer-dux.css" ''
        /**
         * @name Dux
         * @author zekurio
         */

        :root:not(.theme-light) {
        ${declarations variants.dark}}

        :root.theme-light {
        ${declarations variants.light}}
      '';
      target = "${config.xdg.configHome}/fluxer/themes/dux.css";
    };
  };
}
