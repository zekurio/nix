{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.home.pi;
  pi = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
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
    home.packages = [cfg.package];

    home.file =
      {
        ".pi/agent/settings.json".text = builtins.toJSON cfg.settings;
      }
      // lib.mapAttrs' (name: text:
        lib.nameValuePair ".pi/agent/${name}" {inherit text;})
      cfg.contextFiles;
  };
}
