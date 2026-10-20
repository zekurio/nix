{
  flake.modules.nixos.lilith = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (config.home-manager.users.zekurio.theme) hex mix accent base raised surface text white ansi brightAnsi ansiNames;

    negative = [218 68 83];
    neutral = [246 116 0];
    positive = [39 174 96];

    # COSMIC stores colours as 0-1 floats. Nix warns whenever it prints a
    # float it cannot represent exactly, so write them as raw RON with four
    # decimals instead.
    unit = channel: {
      __type = "raw";
      value = let
        scaled = (channel * 10000 + 127) / 255;
      in
        if scaled == 10000
        then "1.0"
        else "0.${lib.fixedWidthString 4 "0" (toString scaled)}";
    };
    # Every builder colour is a RON Option; the ones left unset fall back to
    # COSMIC's dark theme.
    srgb = color: {
      __type = "optional";
      value = lib.listToAttrs (lib.zipListsWith (name: channel: lib.nameValuePair name (unit channel)) ["red" "green" "blue"] color);
    };
    srgba = color: lib.recursiveUpdate (srgb color) {value.alpha = unit 255;};

    colorScheme = config.home-manager.users.zekurio.theme.name;
  in {
    environment.systemPackages = [
      # Papirus ships blue folders; red is its folder colour nearest the accent.
      (pkgs.papirus-icon-theme.override {color = "red";})
    ];

    # COSMIC themes GTK but not Qt, which would otherwise draw light Fusion.
    qt = {
      platformTheme = "gnome";
      style = "adwaita-dark";
    };

    home-manager.users.zekurio = {
      wayland.desktopManager.cosmic.appearance = {
        theme = {
          mode = "dark";
          # The same lightness steps the Plasma scheme used: windows on base,
          # containers on raised, nested containers on surface.
          dark = {
            accent = srgb accent;
            bg_color = srgba base;
            primary_container_bg = srgba raised;
            secondary_container_bg = srgba surface;
            destructive = srgb negative;
            warning = srgb neutral;
            success = srgb positive;
          };
        };
        toolkit = {
          # Also writes the theme into GTK's CSS, which Steam and other GTK
          # apps read.
          apply_theme_global = true;
          icon_theme = "Papirus-Dark";
        };
      };

      programs.ghostty = {
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
    };
  };
}
