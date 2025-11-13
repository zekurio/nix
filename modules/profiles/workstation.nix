{ lib
, pkgs
, config
, inputs
, ...
}:
let
  inherit
    (lib)
    hasAttrByPath
    mkAfter
    mkBefore
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optionalAttrs
    types
    ;

  cfg = config.profiles.workstation;
  hyprCfg = cfg.hyprland;
  hyprEnabled = hyprCfg.enable;

  bravePackage = pkgs':
    pkgs'.brave.override {
      commandLineArgs = [
        "--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,VaapiOnNvidiaGPUs,VaapiIgnoreDriverChecks"
        "--ignore-gpu-blocklist"
        "--enable-zero-copy"
      ];
    };

  basePackages = pkgs': [
    pkgs'.age
    pkgs'.bat
    pkgs'.btop
    pkgs'.eza
    pkgs'.envsubst
    pkgs'.fastfetch
    pkgs'.git
    pkgs'.jq
    pkgs'.nil
    pkgs'.nixd
    pkgs'.sops
    pkgs'.zellij
  ];

  desktopPackages = pkgs': [
    pkgs'.accountsservice
    pkgs'.adw-gtk3
    pkgs'.bibata-cursors
    pkgs'.blueman
    pkgs'.brightnessctl
    (bravePackage pkgs')
    pkgs'.cliphist
    pkgs'.gcr
    pkgs'.grim
    pkgs'.grimblast
    pkgs'.loupe
    pkgs'.matugen
    pkgs'.nautilus
    pkgs'.seahorse
    pkgs'.showtime
    pkgs'.slurp
    pkgs'.wayland-utils
    pkgs'.wl-clip-persist
    pkgs'.wl-clipboard
    pkgs'.xdg-user-dirs
    pkgs'.xdg-user-dirs-gtk
    pkgs'.xwayland-satellite
    pkgs'.unstable.bitwarden-desktop
    pkgs'.unstable.feishin
    pkgs'.unstable.ghostty
    pkgs'.unstable.jetbrains.goland
    pkgs'.unstable.jetbrains.idea-ultimate
    pkgs'.unstable.tsukimi
    pkgs'.unstable.vesktop
    pkgs'.unstable.zed-editor
  ];
in
{
  imports = [
    inputs.dankMaterialShell.nixosModules.greeter
  ];

  options.profiles.workstation = {
    enable =
      mkEnableOption "Managed workstation profile powered by Home Manager"
      // {
        default = true;
      };

    user = mkOption {
      type = types.str;
      default = "zekurio";
      description = "Primary user account managed by the workstation profile.";
    };

    stateVersion = mkOption {
      type = types.str;
      default = "25.05";
      description = "Home Manager stateVersion for the managed user.";
    };

    hyprland = {
      enable = mkEnableOption "Hyprland desktop configuration";

      monitors = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Hyprland monitor layout entries.";
      };

      input = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Hyprland input configuration block.";
      };
    };
  };

  config =
    mkIf cfg.enable (
      mkMerge [
        {
          assertions = [
            {
              assertion = hasAttrByPath [ cfg.user ] config.users.users;
              message = "profiles.workstation.user must reference an existing entry in users.users";
            }
          ];

          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
          };

          home-manager.sharedModules = [
            inputs.dankMaterialShell.homeModules.dankMaterialShell.default
          ];

          home-manager.users.${cfg.user} = { pkgs, ... }:
            mkMerge [
              {
                home = {
                  username = cfg.user;
                  homeDirectory = "/home/${cfg.user}";
                  stateVersion = cfg.stateVersion;
                  enableNixpkgsReleaseCheck = false;
                  packages =
                    basePackages pkgs
                    ++ lib.optionals hyprEnabled (desktopPackages pkgs);
                };

                programs = {
                  direnv = {
                    enable = true;
                    nix-direnv.enable = true;
                  };

                  eza = {
                    enable = true;
                    extraOptions = [
                      "--group-directories-first"
                      "--icons=auto"
                    ];
                  };

                  fish = {
                    enable = true;
                    interactiveShellInit = ''
                      set -g fish_greeting
                    '';
                    plugins = [
                      {
                        name = "pure";
                        src = pkgs.fishPlugins.pure.src;
                      }
                    ];
                  };

                  git = {
                    enable = true;
                    settings = {
                      user.name = "Michael Schwieger";
                      user.email = "git@zekurio.xyz";
                      init.defaultBranch = "main";
                      pull.rebase = true;
                      rebase.autoStash = true;
                      gpg.format = "ssh";
                      gpg.ssh.program = "${pkgs.openssh}/bin/ssh-keygen";
                      user.signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCcQoZiY9wkJ+U93isE8B3CKLmzL7TPzVh3ugE1WPJq";
                      commit.gpgSign = true;
                    };
                  };

                  ssh = {
                    enable = true;
                    enableDefaultConfig = false;
                    matchBlocks."*".compression = true;
                  };
                };
              }
              (mkIf hyprEnabled {
                services.gnome-keyring.enable = true;

                wayland.windowManager.hyprland = {
                  enable = true;
                  settings =
                    mkMerge [
                      {
                        env = [
                          "QT_QPA_PLATFORM,wayland"
                          "ELECTRON_OZONE_PLATFORM_HINT,auto"
                          "QT_QPA_PLATFORMTHEME,gtk3"
                          "QT_QPA_PLATFORMTHEME_QT6,gtk3"
                          "TERMINAL,ghostty"
                        ];

                        exec-once = [
                          "uwsm app -- wl-clip-persist --clipboard both"
                          "uwsm app -- wl-paste --watch cliphist store &"
                          "uwsm app -- dms run"
                          "uwsm app -- /usr/lib/mate-polkit/polkit-mate-authentication-agent-1"
                          "uwsm app -- ghostty --gtk-single-instance=true --quit-after-last-window-closed=false --initial-window=false"
                        ];

                        general = {
                          gaps_in = 5;
                          gaps_out = 5;
                          border_size = 0;
                          "col.active_border" = "rgba(707070ff)";
                          "col.inactive_border" = "rgba(d0d0d0ff)";
                          layout = "dwindle";
                        };

                        decoration = {
                          rounding = 18;
                          shadow = {
                            enabled = true;
                            range = 30;
                            render_power = 5;
                            offset = "0 5";
                            color = "rgba(00000070)";
                          };
                        };

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

                        dwindle = {
                          preserve_split = true;
                        };

                        master = {
                          mfact = 0.5;
                        };

                        misc = {
                          disable_hyprland_logo = true;
                          disable_splash_rendering = true;
                          vrr = 1;
                        };

                        windowrulev2 = [
                          "rounding 18, class:^(org.gnome.)"
                          "noborder, class:^(org.gnome.)"
                          "float, class:^(.blueman-manager-wrapped)$"
                          "size 720 480, class:^(.blueman-manager-wrapped)$"
                          "float, class:^(blender)$, title:^(Blender Render)$"
                          "float, class:^(blender)$, title:^(Preferences)$"
                          "float, class:^(steam)$"
                          "float, class:^(heroic)$"
                          "float, class:^(org.gnome.FileRoller)$"
                          "float, class:^(brave-.*-Default)$"
                          "float, opacity 1, title:^(Picture in picture)$"
                          "float, class:^(xdg-desktop-portal)$"
                          "size 1280 720, class:^(xdg-desktop-portal)$"
                          "float, class:^(xdg-desktop-portal-gtk)$"
                          "size 1280 720, class:^(xdg-desktop-portal-gtk)$"
                          "float, class:^(org.gnome.Showtime)$"
                          "size 1280 720, class:^(org.gnome.Showtime)$"
                          "float, class:^(org.gnome.Loupe)$"
                          "size 1280 720, class:^(org.gnome.Loupe)$"
                          "float, class:^(Bitwarden)$"
                          "size 1280 720, class:^(Bitwarden)$"
                          "float, class:^(org.gnome.Nautilus)$"
                          "size 1280 720, class:^(org.gnome.Nautilus)$"
                          "float, class:^(com.saivert.pwvucontrol)$"
                          "size 1280 720, class:^(com.saivert.pwvucontrol)$"
                          "float, class:^(org.coolercontrol.CoolerControl)$"
                          "size 1280 720, class:^(org.coolercontrol.CoolerControl)$"
                          "noborder, class:^(com.mitchellh.ghostty)$"
                          "workspace special:term, class:^(com.mitchellh.ghostty.zellij)$"
                          "workspace special:comms, class:^(vesktop)$"
                          "workspace special:music, class:^(feishin)$"
                        ];

                        layerrule = [
                          "noanim, ^(quickshell)$"
                        ];

                        "$mainMod" = "Super";
                        "$altMod" = "Alt";
                        "$shiftMod" = "Shift";
                        "$ctrlMod" = "Control";
                        "$mainAlt" = "$mainMod $altMod";
                        "$mainCtrl" = "$mainMod $ctrlMod";
                        "$mainShift" = "$mainMod $shiftMod";
                        "$ctrlShift" = "$ctrlMod $shiftMod";
                        "$ctrlAlt" = "$ctrlMod $altMod";
                        "$handbreaker" = "$mainCtrl $mainShift";

                        bind = [
                          "$mainMod, Return, exec, ghostty"
                          "$mainMod, E, exec, nautilus"
                          "$mainMod, Space, exec, dms ipc call spotlight toggle"
                          "$mainMod, V, exec, dms ipc call clipboard toggle"
                          "$mainMod, M, exec, dms ipc call processlist toggle"
                          "$mainMod, comma, exec, dms ipc call settings toggle"
                          "$mainMod, N, exec, dms ipc call notifications toggle"
                          "$mainShift, N, exec, dms ipc call notepad toggle"
                          "$mainMod, Y, exec, dms ipc call dankdash wallpaper"
                          "$mainMod, TAB, exec, dms ipc call hypr toggleOverview"
                          "$mainMod, L, exec, dms ipc call lock lock"
                          "$mainMod, Escape, exec, dms ipc call powermenu toggle"
                          "CTRL ALT, Delete, exec, dms ipc call processlist toggle"
                          "$mainMod, Q, killactive"
                          "$mainAlt, F, fullscreen, 1"
                          "$mainShift, F, fullscreen, 0"
                          "$mainMod, F, togglefloating"
                          "$mainMod, W, togglegroup"
                          "$mainMod, left, movefocus, l"
                          "$mainMod, down, movefocus, d"
                          "$mainMod, up, movefocus, u"
                          "$mainMod, right, movefocus, r"
                          "$mainMod, H, movefocus, l"
                          "$mainMod, J, movefocus, d"
                          "$mainMod, K, movefocus, u"
                          "$mainMod, L, movefocus, r"
                          "$mainShift, left, movewindow, l"
                          "$mainShift, down, movewindow, d"
                          "$mainShift, up, movewindow, u"
                          "$mainShift, right, movewindow, r"
                          "$mainShift, H, movewindow, l"
                          "$mainShift, J, movewindow, d"
                          "$mainShift, K, movewindow, u"
                          "$mainShift, L, movewindow, r"
                          "$mainMod, Home, focuswindow, first"
                          "$mainMod, End, focuswindow, last"
                          "$mainMod, Page_Down, workspace, e+1"
                          "$mainMod, Page_Up, workspace, e-1"
                          "$mainMod, U, workspace, e+1"
                          "$mainMod, I, workspace, e-1"
                          "$mainCtrl, down, movetoworkspace, e+1"
                          "$mainCtrl, up, movetoworkspace, e-1"
                          "$mainCtrl, U, movetoworkspace, e+1"
                          "$mainCtrl, I, movetoworkspace, e-1"
                          "$mainShift, Page_Down, movetoworkspace, e+1"
                          "$mainShift, Page_Up, movetoworkspace, e-1"
                          "$mainShift, U, movetoworkspace, e+1"
                          "$mainShift, I, movetoworkspace, e-1"
                          "$mainMod, mouse_down, workspace, e+1"
                          "$mainMod, mouse_up, workspace, e-1"
                          "$mainCtrl, mouse_down, movetoworkspace, e+1"
                          "$mainCtrl, mouse_up, movetoworkspace, e-1"
                          "$mainMod, 1, workspace, 1"
                          "$mainMod, 2, workspace, 2"
                          "$mainMod, 3, workspace, 3"
                          "$mainMod, 4, workspace, 4"
                          "$mainMod, 5, workspace, 5"
                          "$mainMod, 6, workspace, 6"
                          "$mainMod, 7, workspace, 7"
                          "$mainMod, 8, workspace, 8"
                          "$mainMod, 9, workspace, 9"
                          "$mainShift, 1, movetoworkspace, 1"
                          "$mainShift, 2, movetoworkspace, 2"
                          "$mainShift, 3, movetoworkspace, 3"
                          "$mainShift, 4, movetoworkspace, 4"
                          "$mainShift, 5, movetoworkspace, 5"
                          "$mainShift, 6, movetoworkspace, 6"
                          "$mainShift, 7, movetoworkspace, 7"
                          "$mainShift, 8, movetoworkspace, 8"
                          "$mainShift, 9, movetoworkspace, 9"
                          "$mainCtrl, F, resizeactive, exact 100%"
                          "$altMod, T, togglespecialworkspace, term"
                          "$altMod, M, togglespecialworkspace, music"
                          "$altMod, C, togglespecialworkspace, comms"
                          "$altMod, S, togglespecialworkspace, scratchpad"
                          '' , Print, exec, bash -lc 'd="$(xdg-user-dir PICTURES)/screenshots"; mkdir -p "$d"; f="$d/$(date +%F_%H-%M-%S).png"; grimblast copysave area "$f" && notify-send -i "$f" "Screenshot saved" "$f"' ''
                          '' $mainMod, Print, exec, bash -lc 'd="$(xdg-user-dir PICTURES)/screenshots"; mkdir -p "$d"; f="$d/$(date +%F_%H-%M-%S).png"; grimblast copysave screen "$f" && notify-send -i "$f" "Screenshot saved" "$f"' ''
                          ", XF86AudioPlay, exec, dms ipc call mpris playPause"
                          ", XF86AudioPause, exec, dms ipc call mpris playPause"
                          ", XF86AudioNext, exec, dms ipc call mpris next"
                          ", XF86AudioPrev, exec, dms ipc call mpris previous"
                        ];

                        bindel = [
                          ", XF86AudioRaiseVolume, exec, dms ipc call audio increment 3"
                          ", XF86AudioLowerVolume, exec, dms ipc call audio decrement 3"
                          ", XF86MonBrightnessUp, exec, dms ipc call brightness increment 5"
                          ", XF86MonBrightnessDown, exec, dms ipc call brightness decrement 5"
                        ];

                        bindl = [
                          ", XF86AudioMute, exec, dms ipc call audio mute"
                          ", XF86AudioMicMute, exec, dms ipc call audio micmute"
                        ];

                        binde = [
                          "$mainMod, minus, resizeactive, -10% 0"
                          "$mainMod, equal, resizeactive, 10% 0"
                          "$mainShift, minus, resizeactive, 0 -10%"
                          "$mainShift, equal, resizeactive, 0 10%"
                        ];

                        bindm = [
                          "$mainMod, mouse:272, movewindow"
                          "$mainMod, mouse:273, resizewindow"
                        ];
                      }
                      (optionalAttrs (hyprCfg.monitors != [ ]) { monitor = hyprCfg.monitors; })
                      (optionalAttrs (hyprCfg.input != { }) { input = hyprCfg.input; })
                    ];
                };

                home.file.".config/BraveSoftware/Brave-Browser/Policies/Managed/policies.json".text = ''
                  {
                    "BraveRewardsDisabled": true,
                    "BraveWalletDisabled": true,
                    "BraveVPNDisabled": 1,
                    "BraveAIChatEnabled": false,
                    "TorDisabled": true,
                    "DnsOverHttpsMode": "automatic"
                  }
                '';

                programs.ghostty = {
                  enable = true;
                  settings = {
                    font-family = "GeistMono Nerd Font Mono";
                    font-size = 12;
                    window-decoration = false;
                    window-padding-x = 12;
                    window-padding-y = 12;
                    background-opacity = 0.90;
                    background-blur-radius = 32;
                    cursor-style = "block";
                    cursor-style-blink = true;
                    scrollback-limit = 3023;
                    mouse-hide-while-typing = true;
                    copy-on-select = false;
                    confirm-close-surface = false;
                    unfocused-split-opacity = 0.7;
                    unfocused-split-fill = "#44464f";
                    gtk-titlebar = false;
                    shell-integration = "detect";
                    shell-integration-features = "cursor,sudo,title,no-cursor";
                    config-file = "./config-dankcolors";
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

                gtk = {
                  enable = true;
                  font.name = "Geist";
                  iconTheme = {
                    name = "Papirus-Dark";
                    package = pkgs.papirus-icon-theme;
                  };
                };

                xdg.userDirs = {
                  enable = true;
                  desktop = "$HOME/Desktop";
                  documents = "$HOME/Documents";
                  download = "$HOME/Downloads";
                  music = "$HOME/Music";
                  pictures = "$HOME/Pictures";
                  publicShare = "$HOME/Public";
                  templates = "$HOME/Templates";
                  videos = "$HOME/Videos";
                };

                home.pointerCursor = {
                  gtk.enable = true;
                  x11.enable = true;
                  package = pkgs.bibata-cursors;
                  name = "Bibata-Modern-Classic";
                  size = 20;
                };

                programs.dankMaterialShell = {
                  enable = true;
                  quickshell.package = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
                };
              })
            ];
        }
        (mkIf hyprEnabled {
          services.gnome.gnome-keyring.enable = mkDefault true;
          security.polkit.enable = true;

          services = {
            accounts-daemon.enable = true;
            dbus.enable = true;
            pipewire = {
              enable = true;
              alsa.enable = true;
              alsa.support32Bit = true;
              pulse.enable = true;
              wireplumber.enable = true;
            };
          };

          programs.hyprland = {
            enable = true;
            withUWSM = true;
            xwayland.enable = true;
          };

          services.seatd.enable = true;
          security.pam.services.greetd.enableGnomeKeyring = true;

          xdg.portal = {
            enable = true;
            extraPortals = mkAfter [
              pkgs.xdg-desktop-portal-gtk
              pkgs.xdg-desktop-portal-hyprland
            ];
            config.common.default = mkBefore [
              "hyprland"
              "gtk"
            ];
          };

          systemd.services.greetd.environment = {
            XCURSOR_THEME = "Bibata-Modern-Classic";
            XCURSOR_SIZE = "20";
            XCURSOR_PATH = "${pkgs.bibata-cursors}/share/icons";
          };

          programs.dankMaterialShell.greeter = {
            enable = true;
            compositor.name = "hyprland";
            configHome = "/home/${cfg.user}";
          };

          users.users.${cfg.user}.extraGroups = mkAfter [
            "audio"
            "render"
            "seat"
          ];

          environment = {
            sessionVariables.NIXOS_OZONE_WL = "1";
            variables = {
              XCURSOR_THEME = "Bibata-Modern-Classic";
              XCURSOR_SIZE = "20";
            };
          };

          fonts.packages = with pkgs; [
            geist-font
            material-symbols
            nerd-fonts.geist-mono
            noto-fonts
            noto-fonts-cjk-sans
            noto-fonts-color-emoji
          ];

          environment.etc."brave/policies/managed/policies.json".text = ''
            {
              "BraveRewardsDisabled": true,
              "BraveWalletDisabled": true,
              "BraveVPNDisabled": 1,
              "BraveAIChatEnabled": false,
              "TorDisabled": true,
              "DnsOverHttpsMode": "automatic"
            }
          '';
        })
      ]
    );
}
