{inputs, ...}: {
  flake.modules.nixos.lilith = {pkgs, ...}: let
    system = pkgs.stdenv.hostPlatform.system;
  in {
    programs = {
      niri.enable = true;

      # DMS 1.5.3 is already native to this nixpkgs revision, so use the
      # NixOS module rather than adding a second DMS flake/package graph.
      dms-shell = {
        enable = true;
        systemd = {
          enable = true;
          target = "niri.service";
        };
        # Application and compositor colors are fixed Catppuccin ports rather
        # than wallpaper-derived Material colors.
        enableDynamicTheming = false;
      };
    };

    services.displayManager = {
      defaultSession = "niri";
      dms-greeter = {
        enable = true;
        compositor.name = "niri";
        configHome = "/home/zekurio";
        compositor.customConfig = ''
          input {
            keyboard {
              xkb {
                layout "at"
              }
            }
          }

          hotkey-overlay {
            skip-at-startup
          }

          layout {
            background-color "#303446"
          }
        '';
      };
    };

    services = {
      pipewire = {
        enable = true;
        alsa = {
          enable = true;
          support32Bit = true;
        };
        pulse.enable = true;
        jack.enable = true;
      };
      pulseaudio.enable = false;
      upower.enable = true;
    };

    security.rtkit.enable = true;

    environment = {
      sessionVariables = {
        NIXOS_OZONE_WL = "1";
        ELECTRON_OZONE_PLATFORM_HINT = "auto";
        QT_QPA_PLATFORM = "wayland";
        QT_QPA_PLATFORMTHEME = "gtk3";
        QT_QPA_PLATFORMTHEME_QT6 = "gtk3";
      };

      systemPackages = with pkgs; [
        ddcutil
        feishin
        libnotify
        mpv
        nautilus
        vesktop
        wl-clipboard
        xwayland-satellite
        inputs.zed.packages.${system}.default
      ];
    };

    home-manager.users.zekurio.xdg.configFile."niri/input.kdl".text = ''
      input {
          keyboard {
              xkb {
                  layout "at"
              }
              numlock
          }

          mouse {
              accel-profile "flat"
          }
      }
    '';
  };
}
