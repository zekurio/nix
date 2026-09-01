{...}: {
  flake.modules.nixos.lilith = {pkgs, ...}: let
    cursorTheme = "BreezeX-RosePine-Linux";
    cursorSize = 28;
  in {
    fonts = {
      packages = with pkgs; [
        fira
        inter
        material-symbols
        nerd-fonts.fira-code
        roboto-slab
      ];
      fontconfig.defaultFonts = {
        sansSerif = ["Fira Sans"];
        serif = ["Roboto Slab"];
        monospace = ["FiraCode Nerd Font Mono"];
      };
    };

    # The compositor starts before Home Manager's shell environment is loaded,
    # so expose the cursor through the display-manager session as well.
    environment.sessionVariables = {
      XCURSOR_THEME = cursorTheme;
      XCURSOR_SIZE = toString cursorSize;
    };

    home-manager.users.zekurio = {
      config,
      lib,
      pkgs,
      ...
    }: let
      catppuccinGtk = pkgs.catppuccin-gtk.override {
        variant = "frappe";
        accents = ["blue"];
      };
      customThemePath = "/home/zekurio/.config/DankMaterialShell/themes/catppuccin-frappe-blue.json";
      dmsTheme = pkgs.writeText "dms-catppuccin-frappe-blue.json" (builtins.toJSON {
        name = "Catppuccin Frappé Blue";
        primary = "#8caaee";
        primaryText = "#232634";
        primaryContainer = "#51576d";
        secondary = "#babbf1";
        surfaceTint = "#8caaee";
        surface = "#303446";
        surfaceText = "#c6d0f5";
        surfaceVariant = "#414559";
        surfaceVariantText = "#b5bfe2";
        background = "#232634";
        backgroundText = "#c6d0f5";
        outline = "#737994";
        surfaceContainerLowest = "#232634";
        surfaceContainerLow = "#292c3c";
        surfaceContainer = "#303446";
        surfaceContainerHigh = "#414559";
        surfaceContainerHighest = "#51576d";
        error = "#e78284";
        warning = "#e5c890";
        info = "#85c1dc";
        success = "#a6d189";
        matugen_type = "scheme-tonal-spot";
      });
      initialDmsSettings = pkgs.writeText "dms-settings.json" (builtins.toJSON {
        currentThemeName = "custom";
        currentThemeCategory = "custom";
        customThemeFile = customThemePath;
        runDmsMatugenTemplates = false;
        gtkThemingEnabled = false;
        qtThemingEnabled = false;
        syncModeWithPortal = true;
        iconThemeDark = "Papirus-Dark";
        iconThemeLight = "Papirus-Dark";
        cursorSettings = {
          theme = cursorTheme;
          size = cursorSize;
          niri = {
            hideWhenTyping = false;
            hideAfterInactiveMs = 0;
          };
          hyprland = {
            hideOnKeyPress = false;
            hideOnTouch = false;
            inactiveTimeout = 0;
          };
          dwl.cursorHideTimeout = 0;
          mango.cursorHideTimeout = 0;
        };
        fontFamily = "Fira Sans";
        monoFontFamily = "FiraCode Nerd Font Mono";
      });
    in {
      fonts.fontconfig.enable = lib.mkForce true;

      gtk = {
        enable = true;
        colorScheme = "dark";
        theme = {
          package = catppuccinGtk;
          name = "catppuccin-frappe-blue-standard";
        };
        gtk4.theme = config.gtk.theme;
        iconTheme.name = "Papirus-Dark";
        font = {
          name = "Fira Sans";
          size = 10;
        };
      };

      qt = {
        enable = true;
        platformTheme.name = "gtk3";
      };

      # The GNOME portal reads this key for the cross-toolkit appearance API.
      # Without it, GTK 4, Qt, Electron, and browsers receive "no preference".
      dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

      home.pointerCursor = {
        enable = true;
        gtk.enable = true;
        x11.enable = true;
        package = pkgs.rose-pine-cursor;
        name = cursorTheme;
        size = cursorSize;
      };

      catppuccin = {
        cursors.enable = false;
        gtk.icon.enable = true;
      };

      xdg = {
        configFile = {
          "DankMaterialShell/themes/catppuccin-frappe-blue.json".source = dmsTheme;

          "niri/config.kdl".text = ''
            config-notification {
                disable-failed
            }

            layout {
                background-color "transparent"
                center-focused-column "never"
                preset-column-widths {
                    proportion 0.33333
                    proportion 0.5
                    proportion 0.66667
                }
                default-column-width { proportion 0.5; }
                border { off; }
                shadow {
                    softness 30
                    spread 5
                    offset x=0 y=5
                    color "#232634b0"
                }
            }

            layer-rule {
                match namespace="^quickshell$"
                place-within-backdrop true
            }

            layer-rule {
                match namespace="^dms:blurwallpaper$"
                place-within-backdrop true
            }

            overview {
                workspace-shadow { off; }
            }

            environment {
                XDG_CURRENT_DESKTOP "niri"
                QT_QPA_PLATFORM "wayland"
                ELECTRON_OZONE_PLATFORM_HINT "auto"
                QT_QPA_PLATFORMTHEME "gtk3"
                QT_QPA_PLATFORMTHEME_QT6 "gtk3"
            }

            hotkey-overlay {
                skip-at-startup
            }

            prefer-no-csd
            screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

            include "input.kdl"

            binds {
                Mod+Return hotkey-overlay-title="Fallback Terminal" { spawn "kitty"; }
                Mod+F1 hotkey-overlay-title="DMS Keybind Cheatsheet" {
                    spawn "dms" "ipc" "call" "keybinds" "toggle" "niri";
                }
                Alt+F4 { close-window; }
                Mod+Shift+Escape { quit; }
            }

            window-rule {
                exclude app-id=r#"^helium$"#
                // Niri automatically restores full opacity while fullscreen.
                opacity 0.95
                background-effect {
                    blur true
                }
            }

            window-rule {
                match app-id=r#"^helium$"#
                match app-id=r#"^kitty$"#
                default-column-width { proportion 1.0; }
            }

            window-rule {
                match app-id=r#"^org\.gnome\."#
                geometry-corner-radius 12
                clip-to-geometry true
            }

            window-rule {
                match app-id=r#"(?i)^1password$"#
                match app-id=r#"^org\.coolercontrol\.CoolerControl$"#
                match app-id=r#"^(com\.heroicgameslauncher\.hgl|heroic)$"#
                match app-id=r#"^org\.gnome\.Nautilus$"#
                match app-id=r#"^org\.gnome\.Calculator$"#
                match app-id=r#"^pavucontrol$"#
                match app-id=r#"(?i)^steam$"#
                open-floating true
            }

            window-rule {
                match app-id=r#"^steam$"# title=r#"^notificationtoasts_\d+_desktop$"#
                default-floating-position x=10 y=10 relative-to="bottom-right"
                open-focused false
            }

            window-rule {
                match app-id=r#"firefox$"# title="^Picture-in-Picture$"
                open-floating true
            }

            include optional=true "dms/colors.kdl"
            include optional=true "dms/layout.kdl"
            include optional=true "dms/alttab.kdl"
            include optional=true "dms/binds.kdl"
            include optional=true "dms/outputs.kdl"
            include "cursor.kdl"
            include optional=true "dms/windowrules.kdl"
            include optional=true "dms/wpblur.kdl"
          '';

          "niri/dms/colors.kdl".text = ''
            // Catppuccin Frappé with blue accents; DMS owns the other fragments.
            layout {
                background-color "transparent"

                focus-ring {
                    active-color "#8caaee"
                    inactive-color "#626880"
                    urgent-color "#e78284"
                }

                border {
                    active-color "#8caaee"
                    inactive-color "#626880"
                    urgent-color "#e78284"
                }

                shadow { color "#232634b0"; }

                tab-indicator {
                    active-color "#8caaee"
                    inactive-color "#626880"
                    urgent-color "#e78284"
                }

                insert-hint { color "#8caaee80"; }
            }

            recent-windows {
                highlight {
                    active-color "#414559"
                    urgent-color "#e78284"
                }
            }
          '';

          # Niri draws the cursor over the desktop and server-side surfaces;
          # GTK settings alone only affect cursors drawn by GTK clients.
          "niri/cursor.kdl".text = ''
            cursor {
                xcursor-theme "${cursorTheme}"
                xcursor-size ${toString cursorSize}
            }
          '';
        };
      };

      # Keep DMS settings mutable after seeding so changes made in its GUI can
      # be saved. Theme, color, and cursor fragments remain immutable.
      home.activation.seedDms = lib.hm.dag.entryAfter ["writeBoundary"] ''
        export XDG_CONFIG_HOME="${config.xdg.configHome}"
        export PATH="${lib.makeBinPath [pkgs.kitty pkgs.niri pkgs.sudo]}:$PATH"

        settings="$XDG_CONFIG_HOME/DankMaterialShell/settings.json"
        $DRY_RUN_CMD mkdir -p "$(dirname "$settings")"
        if [[ ! -e "$settings" ]]; then
          $DRY_RUN_CMD install -m 0600 ${initialDmsSettings} "$settings"
        fi

        for fragment in binds layout alttab outputs windowrules; do
          if [[ ! -e "$XDG_CONFIG_HOME/niri/dms/$fragment.kdl" ]]; then
            $DRY_RUN_CMD ${pkgs.dms-shell}/bin/dms setup "$fragment"
          fi
        done
      '';
    };
  };
}
