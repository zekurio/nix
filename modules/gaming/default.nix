{ lib, pkgs, config, ... }:
let
  cfg = config.modules.gaming;
in
{
  options.modules.gaming = {
    enable = lib.mkEnableOption "Gaming tools: Steam, Heroic, Bottles, and xone driver";

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

    bottles = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install Bottles";
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
      (lib.optional cfg.heroic.enable pkgs.heroic)
      ++ (lib.optional cfg.bottles.enable pkgs.bottles)
    );

    hardware.xone.enable = cfg.xone.enable;
  };
}
