{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.home.pi;
  pi = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
  settingsJson = builtins.toJSON cfg.settings;
in {
  options.home.pi = {
    enable = lib.mkEnableOption "pi coding agent harness";

    package = lib.mkOption {
      type = lib.types.package;
      default = pi;
      description = "pi package to install";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "pi settings.json configuration (see pi docs/settings.md)";
      example = {
        defaultProvider = "anthropic";
        theme = "dark";
        quietStartup = true;
      };
    };

    keybindings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "pi keybindings.json configuration (see pi docs/keybindings.md)";
      example = {
        "app.thinking.cycle" = ["ctrl+r"];
      };
    };

    contextFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.lines;
      default = {};
      description = "AGENTS.md / SYSTEM.md / APPEND_SYSTEM.md files to write to ~/.pi/agent/";
      example = {
        "AGENTS.md" = ''
          Always run nix fmt after editing .nix files.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
      pkgs.nodejs
    ];

    home.activation.piSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
      settings_path="$HOME/.pi/agent/settings.json"
      desired_settings=${lib.escapeShellArg settingsJson}

      mkdir -p "$(dirname "$settings_path")"

      if [ ! -e "$settings_path" ] || [ -L "$settings_path" ]; then
        rm -f "$settings_path"
        printf '%s\n' "$desired_settings" > "$settings_path"
      else
        tmp="$(mktemp)"
        if ${pkgs.jq}/bin/jq -n \
          --argjson desired "$desired_settings" \
          --slurpfile existing "$settings_path" \
          '$desired' \
          > "$tmp"; then
          mv "$tmp" "$settings_path"
        else
          rm -f "$tmp"
          echo "home.pi: failed to merge $settings_path" >&2
          exit 1
        fi
      fi
    '';

    home.file =
      lib.optionalAttrs (cfg.keybindings != {}) {
        ".pi/agent/keybindings.json".text = builtins.toJSON cfg.keybindings;
      }
      // lib.mapAttrs' (name: text:
        lib.nameValuePair ".pi/agent/${name}" {inherit text;})
      cfg.contextFiles;
  };
}
