{inputs, ...}: let
  # Relative to the home directory. The agents live in their own Nix profile so
  # agents-update can move it without a system rebuild.
  profileDir = ".local/state/nix/profiles/agents";

  # Puts the profile's bin, desktop entries and completions on the session paths.
  systemProfile.environment.profiles = ["$HOME/${profileDir}"];
in {
  flake.modules.nixos.base = systemProfile;
  flake.modules.darwin.base = systemProfile;

  flake.modules.homeManager.zekurio = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.agents;
    inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux system;
    attr =
      if cfg.desktop
      then "agents-desktop"
      else "agents";
    profile = lib.escapeShellArg cfg.profile;

    update = pkgs.writeShellApplication {
      name = "agents-update";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        profile=${profile}
        current() { if [ -e "$profile" ]; then readlink -f "$profile"; fi; }
        before=$(current)

        case "''${1:-}" in
          "")
            # Build this flake's environment against the newest agent inputs.
            # flake.lock stays as it is; the weekly update PR catches it up.
            # The URLs repeat those of the two inputs in flake.nix.
            nix build "''${AGENTS_FLAKE:-github:zekurio/nix}#${attr}" \
              --override-input llm-agents github:numtide/llm-agents.nix \
              --override-input t3code-nightly github:vsgoulart/t3code-nightly-flake \
              --refresh --no-write-lock-file --accept-flake-config \
              --no-link --profile "$profile"
            nix-env --profile "$profile" --delete-generations +3
            ${lib.optionalString isDarwin ''
          if command -v brew >/dev/null; then
            brew upgrade --cask --greedy t3-code@nightly
          fi
        ''}
            ;;
          --pinned)
            nix-env --profile "$profile" --set ${cfg.pinned}
            ;;
          --rollback)
            nix-env --profile "$profile" --rollback
            ;;
          *)
            echo "usage: agents-update [--pinned | --rollback]" >&2
            exit 2
            ;;
        esac

        after=$(current)
        if [ "$before" = "$after" ]; then
          echo "The agents are unchanged."
          exit
        fi
        if [ -n "$before" ]; then
          nix store diff-closures "$before" "$after"
        fi
        ${lib.optionalString isLinux ''
          if systemctl is-active --quiet t3code.service 2>/dev/null; then
            echo "t3code.service still runs the old build. A restart ends its sessions:"
            echo "  sudo systemctl restart t3code.service"
          fi
        ''}
      '';
    };
  in {
    options.agents = {
      desktop = lib.mkEnableOption "the T3 Code desktop app in the agents profile";

      profile = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = "${config.home.homeDirectory}/${profileDir}";
        description = "Nix profile that holds the agent CLIs and T3 Code.";
      };

      pinned = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        default = inputs.self.packages.${system}.${attr};
        description = "Agents environment built from the versions in flake.lock.";
      };
    };

    config = {
      home.packages = [update];

      # A rebuild that changes the pinned environment moves the profile to it,
      # so the weekly flake.lock update still reaches every host. Any other
      # activation, including the one at each boot, keeps what agents-update
      # installed.
      home.activation.agentsProfile = lib.hm.dag.entryAfter ["writeBoundary"] ''
        if [ ! -e ${profile} ] || [ "$(cat ${profile}.pinned 2>/dev/null)" != ${cfg.pinned} ]; then
          run mkdir -p "$(dirname ${profile})"
          run nix-env --profile ${profile} --set ${cfg.pinned}
          run sh -c 'echo "$1" > "$2"' _ ${cfg.pinned} ${profile}.pinned
        fi
      '';
    };
  };
}
