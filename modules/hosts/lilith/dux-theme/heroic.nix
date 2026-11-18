{
  home-manager.users.zekurio = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (config.dux.colors) alpha variants;

    # matugen cannot mix colours, but Heroic's Chromium can.
    mix = from: to: percent: "color-mix(in srgb, ${from}, ${to} ${toString percent}%)";

    colors = variant: let
      inherit (variant) accent onAccent accent2 selection onSelection base raised strong sidebar floating text dimText faintText border error ansi;
      hover = color: mix color.hex text.hex 25;
    in
      lib.mapAttrs (_: color: color.hex) {
        # Heroic's palette, which its components also read directly. The
        # darkest neutral doubles as the label on coloured badges and
        # buttons, so it takes on_primary instead of a surface.
        neutral-01 = onAccent;
        neutral-02 = base;
        neutral-03 = raised;
        neutral-04 = border;
        neutral-05 = faintText;
        neutral-06 = dimText;
        neutral-07 = text;
        neutral-08 = text;
        brand-primary = accent;
        brand-secondary = accent2;
        brand-text-01 = text;
        brand-text-02 = dimText;
        brand-text-03 = accent;
        brand-text-04 = accent2;
        brand-text-05 = onSelection;
        status-default = dimText;
        status-success = ansi.green;
        status-warning = ansi.yellow;
        status-danger = error;
        status-info = ansi.blue;
        accent-02 = selection;

        # Windows sit on base and cards on raised, as in Dux. The sidebar
        # takes the darker layer, which also starts the content gradient,
        # and modals the floating layer Legcord's popouts use.
        body-background = base;
        current-background = base;
        background = base;
        background-darker = sidebar;
        background-lighter = raised;
        background-light = base;
        background-secondary = raised;
        background-hover = strong;
        navbar-background = sidebar;
        sidebar-background = sidebar;
        navbar-active-background = selection;
        navbar-active = onSelection;
        navbar-inactive = dimText;
        navbar-accent = accent;
        modal-background = floating;
        modal-border = border;
        input-background = raised;
        search-bar-background = raised;
        search-bar-border = border;
        icons-background = raised;
        osk-background = base;
        osk-button-background = raised;
        osk-button-border = border;
        tour-popup-background = raised;
        divider = border;
        border-color = border;

        text-default = text;
        text-title = text;
        text-primary = text;
        text-secondary = dimText;
        # Button labels on accent, success, warning and danger fills.
        text-tertiary = onAccent;
        text-quartenary = faintText;
        text-hover = accent;
        text-danger = error;
        text-warning = ansi.yellow;
        text-log = ansi.yellow;
        tour-popup-title = text;
        tour-popup-skip-color = dimText;
        tour-popup-skip-color-hover = text;
        tour-bullet-active = accent;
        tour-bullet-inactive = border;

        accent = accent;
        primary = accent;
        primary-button = accent;
        play-button = accent;
        download-button = accent;
        install-button = accent2;
        secondary = accent2;
        secondary-button = accent2;
        link-highlight = accent;
        button-stroke = accent;
        success = ansi.green;
        success-button = ansi.green;
        warning = ansi.yellow;
        tertiary-button = ansi.yellow;
        cancel-button = ansi.yellow;
        danger = error;
        disabled-button = strong;
        disabled-button-overlay = faintText;
        stop-button = strong;

        action-icon = dimText;
        action-icon-hover = accent;
        action-icon-active = text;
        icon-disabled = faintText;

        anticheat-denied = error;
        anticheat-broken = ansi.yellow;
        anticheat-running = ansi.cyan;
        anticheat-supported = ansi.green;
        anticheat-planned = ansi.blue;
        anticheat-unknown = faintText;
      }
      // {
        accent-overlay = hover accent;
        primary-hover = hover accent;
        brand-primary-hover = hover accent;
        primary-active = hover accent;
        secondary-hover = hover accent2;
        secondary-button-overlay = hover accent2;
        brand-secondary-hover = hover accent2;
        status-success-hover = hover ansi.green;
        success-hover = hover ansi.green;
        status-warning-hover = hover ansi.yellow;
        warning-hover = hover ansi.yellow;
        tertiary-button-overlay = hover ansi.yellow;
        cancel-button-overlay = hover ansi.yellow;
        status-danger-hover = hover error;
        danger-hover = hover error;
        status-default-hover = hover dimText;
        status-info-hover = hover ansi.blue;
        download-button-overlay = hover accent;

        # The scrims behind modals and game card titles.
        background-darker-80 = alpha sidebar 80;
        modal-backdrop = alpha sidebar 80;
        gamecard-title-color = alpha sidebar 85;
      };

    declarations = variant: lib.concatStrings (lib.mapAttrsToList (name: value: "  --${name}: ${value};\n") (colors variant));

    # Spots where Heroic hardcodes a colour, or pairs two that only read on
    # its dark themes. The round play, download and stop buttons draw their
    # glyph as a near-black path over the circle.
    fixes = ''
      body.dux button svg:has(> circle) > path,
      body.dux .playIcon > span {
        fill: var(--text-tertiary);
        color: var(--text-tertiary);
      }

      body.dux .offline-message button {
        color: inherit;
      }

      /* Warnings sit on the error colour but print in the text colour. */
      body.dux .WarningMessage {
        color: var(--text-tertiary);
      }

      body.dux .wineManager .gameListHeader span {
        color: var(--text-secondary);
      }

      /* Heroic draws accent lines between Wine versions; Dux divides lists
         with its border colour. */
      body.dux .wineItem {
        border-bottom-color: var(--border-color);
      }
    '';
  in {
    # Heroic lists every .css file in its custom themes folder and gives
    # <body> the file name as its class, so dux.css styles body.dux. Set
    # Settings > General > Custom Themes Path to the folder once and pick
    # "dux.css" as the theme. Heroic reads the file only when it applies the
    # theme, so new wallpaper colours show after Heroic restarts. Light and
    # dark switch live: Dux sets the portal colour scheme, which Electron
    # reports as prefers-color-scheme.
    dux.templates.heroic = {
      source = pkgs.writeText "heroic-dux.css" ''
        body.dux {
        ${declarations variants.dark}}

        @media (prefers-color-scheme: light) {
          body.dux {
        ${declarations variants.light}  }
        }

        ${fixes}
      '';
      target = "${config.xdg.configHome}/heroic/themes/dux.css";
    };
  };
}
