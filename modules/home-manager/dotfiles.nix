{
  lib,
  config,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.homeManager.dotfiles;
in
{
  options.modules.homeManager.dotfiles = {
    enable = mkEnableOption "Dotfiles management for user configuration files";

    hyprland = {
      enable = mkEnableOption "Hyprland declarative configuration";
    };

    ghostty = {
      enable = mkEnableOption "Ghostty terminal emulator configuration";
    };
  };

  config = mkIf cfg.enable {
    home-manager.users.zekurio = {
      wayland.windowManager.hyprland = mkIf cfg.hyprland.enable {
        enable = true;
        settings = {
          # Monitor configuration
          monitor = "DP-2,2560x1440@165,2560x0,1,vrr,1";

          # Environment variables
          env = [
            "QT_QPA_PLATFORM,wayland"
            "ELECTRON_OZONE_PLATFORM_HINT,auto"
            "QT_QPA_PLATFORMTHEME,gtk3"
            "QT_QPA_PLATFORMTHEME_QT6,gtk3"
            "TERMINAL,ghostty"
          ];

          # Startup applications
          exec-once = [
            "wl-clip-persist --clipboard both"
            "wl-paste --watch cliphist store &"
            "dms run"
            "/usr/lib/mate-polkit/polkit-mate-authentication-agent-1"
          ];

          # Input configuration
          input = {
            kb_layout = "eu";
            numlock_by_default = true;
            accel_profile = "flat";
          };

          # General layout
          general = {
            gaps_in = 5;
            gaps_out = 5;
            border_size = 0;
            "col.active_border" = "rgba(707070ff)";
            "col.inactive_border" = "rgba(d0d0d0ff)";
            layout = "dwindle";
          };

          # Decoration
          decoration = {
            rounding = 6;
            active_opacity = 1.0;
            inactive_opacity = 0.9;
            shadow = {
              enabled = true;
              range = 30;
              render_power = 5;
              offset = "0 5";
              color = "rgba(00000070)";
            };
          };

          # Animations
          animations = {
            enabled = true;
            animation = [
              "windowsIn, 1, 3, default"
              "windowsOut, 1, 3, default"
              "workspaces, 1, 5, default"
              "windowsMove, 1, 4, default"
              "fade, 1, 3, default"
              "border, 1, 3, default"
            ];
          };

          # Layouts
          dwindle = {
            preserve_split = true;
          };

          master = {
            mfact = 0.5;
          };

          # Misc settings
          misc = {
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
            vrr = 1;
          };

          # Window rules
          windowrulev2 = [
            "rounding 6, class:^(org\\.gnome\\.)"
            "noborder, class:^(org\\.gnome\\.)"
            "tile, class:^(pavucontrol)$"
            "tile, class:^(nm-connection-editor)$"
            "float, class:^(blueman-manager)$"
            "float, class:^(steam)$"
            "float, class:^(xdg-desktop-portal)$"
            "float, class:^(org.gnome.Showtime)$"
            "float, class:^(org.gnome.Loupe)$"
            "noborder, class:^(com\\.mitchellh\\.ghostty)$"
            "float, class:^(firefox)$, title:^(Picture-in-Picture)$"
            "opacity 0.9 0.9, floating:0, focus:0"
          ];

          # Layer rules
          layerrule = [
            "noanim, ^(quickshell)$"
          ];

          # Define modifier
          "$mod" = "SUPER";

          # Keybindings
          bind = [
            # Application Launchers
            "$mod, T, exec, ghostty"
            "$mod, space, exec, dms ipc call spotlight toggle"
            "$mod, V, exec, dms ipc call clipboard toggle"
            "$mod, M, exec, dms ipc call processlist toggle"
            "$mod, comma, exec, dms ipc call settings toggle"
            "$mod, N, exec, dms ipc call notifications toggle"
            "$mod SHIFT, N, exec, dms ipc call notepad toggle"
            "$mod, Y, exec, dms ipc call dankdash wallpaper"
            "$mod, TAB, exec, dms ipc call hypr toggleOverview"

            # Security
            "$mod, L, exec, dms ipc call lock lock"
            "$mod SHIFT, E, exit"
            "CTRL ALT, Delete, exec, dms ipc call processlist toggle"

            # Window Management
            "$mod, Q, killactive"
            "$mod, F, fullscreen, 1"
            "$mod SHIFT, F, fullscreen, 0"
            "$mod SHIFT, T, togglefloating"
            "$mod, W, togglegroup"

            # Focus Navigation
            "$mod, left, movefocus, l"
            "$mod, down, movefocus, d"
            "$mod, up, movefocus, u"
            "$mod, right, movefocus, r"
            "$mod, H, movefocus, l"
            "$mod, J, movefocus, d"
            "$mod, K, movefocus, u"
            "$mod, L, movefocus, r"

            # Window Movement
            "$mod SHIFT, left, movewindow, l"
            "$mod SHIFT, down, movewindow, d"
            "$mod SHIFT, up, movewindow, u"
            "$mod SHIFT, right, movewindow, r"
            "$mod SHIFT, H, movewindow, l"
            "$mod SHIFT, J, movewindow, d"
            "$mod SHIFT, K, movewindow, u"
            "$mod SHIFT, L, movewindow, r"

            # Column Navigation
            "$mod, Home, focuswindow, first"
            "$mod, End, focuswindow, last"

            # Monitor Navigation
            "$mod CTRL, left, focusmonitor, l"
            "$mod CTRL, right, focusmonitor, r"
            "$mod CTRL, H, focusmonitor, l"
            "$mod CTRL, J, focusmonitor, d"
            "$mod CTRL, K, focusmonitor, u"
            "$mod CTRL, L, focusmonitor, r"

            # Move to Monitor
            "$mod SHIFT CTRL, left, movewindow, mon:l"
            "$mod SHIFT CTRL, down, movewindow, mon:d"
            "$mod SHIFT CTRL, up, movewindow, mon:u"
            "$mod SHIFT CTRL, right, movewindow, mon:r"
            "$mod SHIFT CTRL, H, movewindow, mon:l"
            "$mod SHIFT CTRL, J, movewindow, mon:d"
            "$mod SHIFT CTRL, K, movewindow, mon:u"
            "$mod SHIFT CTRL, L, movewindow, mon:r"

            # Workspace Navigation
            "$mod, Page_Down, workspace, e+1"
            "$mod, Page_Up, workspace, e-1"
            "$mod, U, workspace, e+1"
            "$mod, I, workspace, e-1"
            "$mod CTRL, down, movetoworkspace, e+1"
            "$mod CTRL, up, movetoworkspace, e-1"
            "$mod CTRL, U, movetoworkspace, e+1"
            "$mod CTRL, I, movetoworkspace, e-1"

            # Move Workspaces
            "$mod SHIFT, Page_Down, movetoworkspace, e+1"
            "$mod SHIFT, Page_Up, movetoworkspace, e-1"
            "$mod SHIFT, U, movetoworkspace, e+1"
            "$mod SHIFT, I, movetoworkspace, e-1"

            # Mouse Wheel Navigation
            "$mod, mouse_down, workspace, e+1"
            "$mod, mouse_up, workspace, e-1"
            "$mod CTRL, mouse_down, movetoworkspace, e+1"
            "$mod CTRL, mouse_up, movetoworkspace, e-1"

            # Numbered Workspaces
            "$mod, 1, workspace, 1"
            "$mod, 2, workspace, 2"
            "$mod, 3, workspace, 3"
            "$mod, 4, workspace, 4"
            "$mod, 5, workspace, 5"
            "$mod, 6, workspace, 6"
            "$mod, 7, workspace, 7"
            "$mod, 8, workspace, 8"
            "$mod, 9, workspace, 9"

            # Move to Numbered Workspaces
            "$mod SHIFT, 1, movetoworkspace, 1"
            "$mod SHIFT, 2, movetoworkspace, 2"
            "$mod SHIFT, 3, movetoworkspace, 3"
            "$mod SHIFT, 4, movetoworkspace, 4"
            "$mod SHIFT, 5, movetoworkspace, 5"
            "$mod SHIFT, 6, movetoworkspace, 6"
            "$mod SHIFT, 7, movetoworkspace, 7"
            "$mod SHIFT, 8, movetoworkspace, 8"
            "$mod SHIFT, 9, movetoworkspace, 9"

            # Column Management
            "$mod, bracketleft, layoutmsg, preselect l"
            "$mod, bracketright, layoutmsg, preselect r"

            # Sizing & Layout
            "$mod, R, layoutmsg, togglesplit"
            "$mod CTRL, F, resizeactive, exact 100%"

            # Screenshots
            ", XF86Launch1, exec, grimblast copy area"
            "CTRL, XF86Launch1, exec, grimblast copy screen"
            "ALT, XF86Launch1, exec, grimblast copy active"
            ", Print, exec, grimblast copy area"
            "CTRL, Print, exec, grimblast copy screen"
            "ALT, Print, exec, grimblast copy active"

            # System Controls
            "$mod SHIFT, P, dpms, off"
          ];

          # Audio controls with repeat
          bindel = [
            ", XF86AudioRaiseVolume, exec, dms ipc call audio increment 3"
            ", XF86AudioLowerVolume, exec, dms ipc call audio decrement 3"
            ", XF86KbdBrightnessUp, exec, kbdbrite.sh up"
            ", XF86KbdBrightnessDown, exec, kbdbrite.sh down"
            ", XF86MonBrightnessUp, exec, dms ipc call brightness increment 5"
            ", XF86MonBrightnessDown, exec, dms ipc call brightness decrement 5"
          ];

          # Audio toggle bindings
          bindl = [
            ", XF86AudioMute, exec, dms ipc call audio mute"
            ", XF86AudioMicMute, exec, dms ipc call audio micmute"
          ];

          # Manual sizing with repeat
          binde = [
            "$mod, minus, resizeactive, -10% 0"
            "$mod, equal, resizeactive, 10% 0"
            "$mod SHIFT, minus, resizeactive, 0 -10%"
            "$mod SHIFT, equal, resizeactive, 0 10%"
          ];

          # Mouse bindings with descriptions
          bindm = [
            "$mod, mouse:272, movewindow"
            "$mod, mouse:273, resizewindow"
          ];

          # Description bindings (for resize with keys)
          bindd = [
            "$mod, code:20, Expand window left, resizeactive, -100 0"
            "$mod, code:21, Shrink window left, resizeactive, 100 0"
          ];
        };
      };

      programs.ghostty = mkIf cfg.ghostty.enable {
        enable = true;
        settings = {
          # Font Configuration
          font-family = "Fira Code";
          font-size = 12;

          # Window Configuration
          window-decoration = false;
          window-padding-x = 12;
          window-padding-y = 12;
          background-opacity = 0.90;
          background-blur-radius = 32;

          # Cursor Configuration
          cursor-style = "block";
          cursor-style-blink = true;

          # Scrollback
          scrollback-limit = 3023;

          # Terminal features
          mouse-hide-while-typing = true;
          copy-on-select = false;
          confirm-close-surface = false;

          # Material 3 UI elements
          unfocused-split-opacity = 0.7;
          unfocused-split-fill = "#44464f";

          # Tab configuration
          gtk-titlebar = false;

          # Shell integration
          shell-integration = "detect";
          shell-integration-features = "cursor,sudo,title,no-cursor";

          # Dank color generation
          config-file = "./config-dankcolors";

          # Key bindings for common actions
          keybind = [
            "ctrl+shift+n=new_window"
            "ctrl+t=new_tab"
            "ctrl+plus=increase_font_size:1"
            "ctrl+minus=decrease_font_size:1"
            "ctrl+zero=reset_font_size"
            "shift+enter=text:\\n"
          ];
        };
      };
    };
  };
}
