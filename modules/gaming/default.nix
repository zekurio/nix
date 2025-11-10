{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.modules.gaming;
in {
  options.modules.gaming = {
    enable = lib.mkEnableOption "Gaming tools: Steam, Heroic, and xone driver";

    steam = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Steam and related support";
      };
    };

    heroic = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install Heroic Game Launcher";
      };
    };

    xone = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the xone Xbox One controller driver";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.steam.enable = cfg.steam.enable;

    environment.systemPackages = lib.mkAfter (
      lib.optional cfg.heroic.enable pkgs.unstable.heroic
    );

    hardware.xone.enable = cfg.xone.enable;
  };
}
