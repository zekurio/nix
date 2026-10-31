{
  config,
  lib,
  pkgs,
  ...
}: let
  sshTint = pkgs.writeShellApplication {
    name = "ghostty-ssh-tint";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      # %C hashes the connection details into a safe shell argument.
      # %f fails during LocalCommand expansion with OpenSSH 10.5.
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
      # Light mode keeps the hue and lifts the channels to 200..224.
      if [[ "''${GHOSTTY_SSH_TINT_SCHEME:-}" == light ]]; then
        rgb=($(( rgb[0] + 169 )) $(( rgb[1] + 169 )) $(( rgb[2] + 169 )))
      fi
      printf '\033]11;#%02x%02x%02x\007' "''${rgb[@]}" > /dev/tty
    '';
  };

  # Ghostty answers CSI ? 996 n with CSI ? 997 ; 1 n for dark and ; 2 n for
  # light. Ask before ssh starts, because ssh owns the TTY by LocalCommand.
  colorScheme = pkgs.writeShellApplication {
    name = "ghostty-color-scheme";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      if ! saved=$(stty -g 2> /dev/null < /dev/tty); then
        echo dark
        exit 0
      fi
      trap 'stty "$saved" < /dev/tty' EXIT
      stty -echo -icanon < /dev/tty
      printf '\033[?996n' > /dev/tty
      reply=
      IFS= read -r -s -d n -t 0.5 reply < /dev/tty || true
      case $reply in
        *'?997;2') echo light ;;
        *) echo dark ;;
      esac
    '';
  };
in {
  config = {
    programs.fish = lib.mkIf config.programs.ghostty.enable {
      functions.ssh = {
        wraps = "ssh";
        description = "Tint Ghostty for each SSH connection";
        body = ''
          if not status is-interactive; or test "$TERM_PROGRAM" != ghostty; or set -q TMUX; or not isatty stdin; or not isatty stdout
            command ssh $argv
            return $status
          end

          set -g __ghostty_ssh_tinted 1
          set -lx GHOSTTY_SSH_TINT_SCHEME (${lib.getExe colorScheme})
          # Multiplexed sessions skip LocalCommand, so disable sharing for tint.
          command ssh -S none \
            -o PermitLocalCommand=yes \
            -o 'LocalCommand=${lib.getExe sshTint} %C' $argv
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
      enable = lib.mkDefault pkgs.stdenv.hostPlatform.isDarwin;
      # macOS installs Ghostty from Homebrew.
      package =
        if pkgs.stdenv.hostPlatform.isDarwin
        then null
        else pkgs.ghostty;
      systemd.enable = false;
      settings =
        {
          window-width = 150;
          window-height = 38;
          window-save-state = "never";
          window-padding-x = 10;
          window-padding-y = 8;
          background-blur = true;
          background-opacity = 0.96;
          font-family = "FiraCode Nerd Font";
          # Linux lays out points at 96 DPI and macOS at 72, so the same
          # glyph height needs 4/3 the point size on Darwin.
          font-size =
            if pkgs.stdenv.hostPlatform.isDarwin
            then 16
            else 12;
          term = "xterm-256color";
          window-inherit-font-size = false;
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          macos-titlebar-style = "transparent";
        };
    };
  };
}
