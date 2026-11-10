{
  config,
  lib,
  pkgs,
  ...
}: let
  sshTint = pkgs.writeShellApplication {
    name = "ssh-tint";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      # %C hashes the connection details into a safe shell argument.
      # %f fails during LocalCommand expansion with OpenSSH 10.5.
      [[ -n "''${1:-}" ]] || exit 0
      read -r checksum _ < <(printf '%s' "$1" | cksum)

      # Quantize the hue wheel into 32 tints, with channel offsets 0..24.
      hue=$(( (checksum % 32) * 6 ))
      rising=$(( 24 * (hue % 32) / 32 ))
      falling=$(( 24 - rising ))
      case $(( hue / 32 )) in
        0) offset=(24 "$rising" 0) ;;
        1) offset=("$falling" 24 0) ;;
        2) offset=(0 24 "$rising") ;;
        3) offset=(0 "$falling" 24) ;;
        4) offset=("$rising" 0 24) ;;
        5) offset=(24 0 "$falling") ;;
      esac

      # Tint relative to the real background, since a fixed range can sit on
      # top of the theme's own background and vanish. A dark background
      # lifts by 9..33 and a light one drops by 21..45. Without a reply,
      # assume #161616, which gives the original tints.
      read -r -a base <<< "''${SSH_TINT_BACKGROUND:-}"
      [[ ''${#base[@]} -eq 3 ]] || base=(22 22 22)
      if (( (299 * base[0] + 587 * base[1] + 114 * base[2]) / 1000 > 127 )); then
        lift=-45
      else
        lift=9
      fi
      rgb=()
      for i in 0 1 2; do
        channel=$(( base[i] + lift + offset[i] ))
        (( channel < 0 )) && channel=0
        (( channel > 255 )) && channel=255
        rgb+=("$channel")
      done
      printf '\033]11;#%02x%02x%02x\007' "''${rgb[@]}" > /dev/tty
    '';
  };

  # OSC 11 ; ? asks for the background, and Ghostty answers with
  # OSC 11 ; rgb:RRRR/GGGG/BBBB BEL. Ask before ssh starts, because ssh owns
  # the TTY by LocalCommand. Prints the 8-bit channels, or nothing.
  background = pkgs.writeShellApplication {
    name = "terminal-background";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      saved=$(stty -g 2> /dev/null < /dev/tty) || exit 0
      trap 'stty "$saved" < /dev/tty' EXIT
      stty -echo -icanon < /dev/tty
      printf '\033]11;?\007' > /dev/tty
      reply=
      IFS= read -r -s -d $'\a' -t 0.5 reply < /dev/tty || true
      pattern='rgb:([0-9a-fA-F]{2})[0-9a-fA-F]*/([0-9a-fA-F]{2})[0-9a-fA-F]*/([0-9a-fA-F]{2})'
      if [[ $reply =~ $pattern ]]; then
        echo "$(( 16#''${BASH_REMATCH[1]} )) $(( 16#''${BASH_REMATCH[2]} )) $(( 16#''${BASH_REMATCH[3]} ))"
      fi
    '';
  };
in {
  # Ghostty only. On kitty the tint clashes with the colours Dux generates.
  programs.fish = lib.mkIf config.programs.ghostty.enable {
    functions.ssh = {
      wraps = "ssh";
      description = "Tint the terminal background for each SSH connection";
      body = ''
        if not status is-interactive; or test "$TERM_PROGRAM" != ghostty; or set -q TMUX; or not isatty stdin; or not isatty stdout
          command ssh $argv
          return $status
        end

        set -g __ssh_tinted 1
        set -lx SSH_TINT_BACKGROUND (${lib.getExe background})
        # Multiplexed sessions skip LocalCommand, so disable sharing for tint.
        command ssh -S none \
          -o PermitLocalCommand=yes \
          -o 'LocalCommand=${lib.getExe sshTint} %C' $argv
        set -l ssh_status $status
        printf '\e]111\a'
        set -e __ssh_tinted
        return $ssh_status
      '';
    };
    interactiveShellInit = ''
      # Fish can abort the wrapper on Ctrl-C. Restore at the next prompt too.
      function __ssh_tint_reset --on-event fish_prompt
        if set -q __ssh_tinted
          printf '\e]111\a'
          set -e __ssh_tinted
        end
      end
    '';
  };
}
