{
  home-manager.users.zekurio = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.dux = {
      templates = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            source = lib.mkOption {
              type = lib.types.path;
              description = "matugen template, written with the placeholders in dux.colors.";
            };
            target = lib.mkOption {
              type = lib.types.str;
              description = "Absolute path matugen writes the rendered template to.";
            };
            postHook = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Shell command matugen runs after writing target.";
            };
          };
        });
        default = {};
        description = "matugen templates Dux renders alongside its own.";
      };

      colors = lib.mkOption {
        type = lib.types.attrs;
        readOnly = true;
        description = "matugen placeholders for Dux's current colour scheme.";
        default = let
          # matugen 4.2 has no filter that mixes two colours, and set_alpha
          # rejects the formats the apps here read. The channels let rgba()
          # add the alpha instead.
          placeholder = namespace: name: mode: let
            field = format: "{{${namespace}.${name}.${mode}.${format}}}";
          in {
            hex = field "hex";
            # Bare "r,g,b", the form DiscordRecolor takes.
            rgb = "${field "red"},${field "green"},${field "blue"}";
            # HSL lightness in percent.
            lightness = field "lightness";
          };

          hues = ["red" "green" "yellow" "blue" "magenta" "cyan"];

          variant = mode: layers: let
            role = name: placeholder "colors" name mode;
            # Dux imports its dank16 palette for user templates. Only red,
            # green and yellow keep their own hue: blue is the primary hue
            # at text contrast, magenta primary_container and cyan primary.
            # dank16term is the same palette after Dux's "Colors from
            # wallpaper" setting pulls red, green and yellow toward the
            # primary, which kitty prints with.
            slot = namespace: index: placeholder namespace "color${toString index}" mode;
            ansiFrom = namespace: offset:
              lib.listToAttrs (lib.imap1 (index: name: lib.nameValuePair name (slot namespace (index + offset))) hues)
              // {
                black = slot namespace offset;
                white = slot namespace (offset + 7);
              };
          in
            lib.mapAttrs (_: role) layers
            // {
              inherit mode;
              accent = role "primary";
              onAccent = role "on_primary";
              accentContainer = role "primary_container";
              onAccentContainer = role "on_primary_container";
              # A second accent for tags and badges.
              accent2 = role "tertiary";
              selection = role "secondary_container";
              onSelection = role "on_secondary_container";
              highlight = role "tertiary_container";
              onHighlight = role "on_tertiary_container";
              text = role "on_surface";
              dimText = role "on_surface_variant";
              # Timestamps, placeholders and disabled text.
              faintText = role "outline";
              border = role "outline_variant";
              error = role "error";
              # Status colours, which keep their hue whatever the terminal
              # setting.
              ansi = ansiFrom "dank16" 0;
              brightAnsi = ansiFrom "dank16" 8;
              # For terminal output shown inside apps, so it matches kitty.
              terminalAnsi = ansiFrom "dank16term" 0;
              terminalBrightAnsi = ansiFrom "dank16term" 8;
            };
        in {
          alpha = color: percent: "rgba(${color.rgb}, ${toString percent}%)";

          # Discord layers its sidebars and frame behind the chat, darker in
          # dark mode and toward the text in light mode, with popouts above
          # the chat. In dark mode this follows Dux's own ladder: windows on
          # surface, cards on surface_container. surface_container_lowest
          # is pure black there, which Dux itself never paints. In light
          # mode surface is lighter than every container but the lowest,
          # which popouts take.
          variants = {
            dark = variant "dark" {
              base = "surface_container";
              raised = "surface_container_high";
              surface = "surface_container_highest";
              # Hover and pressed fills a step past surface.
              strong = "surface_bright";
              sidebar = "surface_container_low";
              panel = "surface";
              frame = "surface";
              floating = "surface";
              # An accent white text reads on, for apps that hardcode white
              # button labels. Dark primary is too pale for that.
              filledAccent = "inverse_primary";
            };
            light = variant "light" {
              base = "surface";
              raised = "surface_container";
              surface = "surface_container_high";
              strong = "surface_dim";
              sidebar = "surface_container_low";
              panel = "surface_container";
              frame = "surface_container_highest";
              floating = "surface_container_lowest";
              filledAccent = "primary";
            };
          };
        };
      };
    };

    # Dux runs matugen on every wallpaper or theme change and appends each
    # file in this folder to its own config. Its ~/.config/matugen/config.toml
    # route needs a bare [templates] header that pkgs.formats.toml does not
    # write. matugen renders the dark and light scheme on every run, so apps
    # that switch with the system appearance get both variants.
    config.xdg.configFile."matugen/dms/configs/lilith.toml" = lib.mkIf (config.dux.templates != {}) {
      source = (pkgs.formats.toml {}).generate "dux-templates.toml" {
        templates = lib.mapAttrs' (name: template:
          lib.nameValuePair "lilith-${name}" ({
              input_path = "${template.source}";
              output_path = template.target;
            }
            // lib.optionalAttrs (template.postHook != null) {
              post_hook = template.postHook;
            }))
        config.dux.templates;
      };
    };
  };
}
