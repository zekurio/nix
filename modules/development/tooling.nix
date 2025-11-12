{ lib, config, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf mkAfter;
  cfg = config.modules.development.tooling;
in
{
  options.modules.development.tooling = {
    enable =
      mkEnableOption "System-wide development tooling"
      // {
        default = false;
      };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = mkAfter [
      pkgs.gh
      pkgs.unstable.codex
      pkgs.unstable.opencode
    ];
  };
}
