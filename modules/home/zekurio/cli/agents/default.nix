{
  flake.modules.homeManager.zekurio = {pkgs, ...}: let
    agentFlake = "github:numtide/llm-agents.nix";
    agentNames = [
      "codex"
      "opencode"
    ];
    agentsProfileBin = "$HOME/.local/state/nix/profiles/agents/bin";

    agentsUpdate = pkgs.writeShellApplication {
      name = "agents-update";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.jq
        pkgs.nix
      ];
      text = ''
        profile="$HOME/.local/state/nix/profiles/agents"
        profile_json='{"elements":{}}'

        if [[ -e "$profile" ]]; then
          profile_json="$(nix profile list --profile "$profile" --json)"
        fi

        mapfile -t unwanted < <(
          jq --raw-output --argjson desired '${builtins.toJSON agentNames}' \
            '.elements | keys[] | select(. as $name | ($desired | index($name)) == null)' \
            <<<"$profile_json"
        )
        if (( ''${#unwanted[@]} > 0 )); then
          nix profile remove --profile "$profile" "''${unwanted[@]}"
        fi

        missing=()
        for name in ${builtins.concatStringsSep " " agentNames}; do
          if ! jq --exit-status --arg suffix ".$name" \
            '.elements | any(.[]; .attrPath | endswith($suffix))' \
            <<<"$profile_json" >/dev/null
          then
            missing+=("${agentFlake}#$name")
          fi
        done

        if (( ''${#missing[@]} > 0 )); then
          nix profile add --accept-flake-config --profile "$profile" "''${missing[@]}"
        fi

        nix profile upgrade --accept-flake-config --all --profile "$profile"
        nix profile list --profile "$profile"
      '';
    };

    agentsRollback = pkgs.writeShellApplication {
      name = "agents-rollback";
      runtimeInputs = [pkgs.nix];
      text = ''
        profile="$HOME/.local/state/nix/profiles/agents"

        if [[ ! -e "$profile" ]]; then
          echo "The agents profile has not been initialized." >&2
          exit 1
        fi

        nix profile rollback --profile "$profile"
        nix profile list --profile "$profile"
      '';
    };
  in {
    # Keep fast-moving agent binaries outside the Home Manager generation so
    # they can be upgraded or rolled back without activating the host.
    home.sessionPath = [agentsProfileBin];
    home.packages = [
      agentsRollback
      agentsUpdate
    ];
  };
}
