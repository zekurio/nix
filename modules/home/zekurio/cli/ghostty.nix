{
  flake.modules.homeManager.zekurio = {
    lib,
    pkgs,
    ...
  }: let
    sshTint = pkgs.writeShellApplication {
      name = "ghostty-ssh-tint";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        # LocalCommand supplies the authenticated host key, including for aliases
        # and ProxyJump destinations. Never probe a separate, unverified key.
        [[ -n "''${1:-}" ]] || exit 0
        read -r checksum _ < <(printf '%s' "$1" | cksum)

        # Quantize the hue wheel into 32 dark tints, with RGB channels 31..55.
        hue=$(( (checksum % 32) * 6 ))
        rising=$(( 31 + 24 * (hue % 32) / 32 ))
        falling=$(( 55 - 24 * (hue % 32) / 32 ))
        case $(( hue / 32 )) in
          0) rgb=(55 "$rising" 31) ;;
          1) rgb=("$falling" 55 31) ;;
          2) rgb=(31 55 "$rising") ;;
          3) rgb=(31 "$falling" 55) ;;
          4) rgb=("$rising" 31 55) ;;
          5) rgb=(55 31 "$falling") ;;
        esac
        printf '\033]11;#%02x%02x%02x\007' "''${rgb[@]}" > /dev/tty
      '';
    };
  in {
    config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      programs.fish = {
        functions.ssh = {
          wraps = "ssh";
          description = "Tint Ghostty using the SSH host key";
          body = ''
            if not status is-interactive; or test "$TERM_PROGRAM" != ghostty; or set -q TMUX; or not isatty stdin; or not isatty stdout
              command ssh $argv
              return $status
            end

            set -g __ghostty_ssh_tinted 1
            # Multiplexed sessions skip LocalCommand and expose no fingerprint.
            command ssh -S none \
              -o PermitLocalCommand=yes \
              -o 'LocalCommand=${lib.getExe sshTint} %f' $argv
            set -l ssh_status $status
            printf '\e]111\a'
            set -e __ghostty_ssh_tinted
            return $ssh_status
          '';
        };
        interactiveShellInit = ''
          # Fish can abort the wrapper on Ctrl-C. Restore at the next prompt too.
          function __ghostty_ssh_reset --on-event fish_prompt
            if set -q __ghostty_ssh_tinted
              printf '\e]111\a'
              set -e __ghostty_ssh_tinted
            end
          end
        '';
      };

      programs.ghostty = {
        enable = true;
        package = null;
        enableFishIntegration = true;
        systemd.enable = false;
        settings = {
          window-width = 150;
          window-height = 38;
          window-save-state = "never";
          window-padding-x = 10;
          window-padding-y = 8;
          background-blur = true;
          background-opacity = 0.96;
          font-family = "FiraCode Nerd Font";
          font-size = 14;
          term = "xterm-256color";
          window-inherit-font-size = false;
          macos-titlebar-style = "transparent";
        };
      };
    };
  };
}
