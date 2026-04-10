{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.modules.gaming;
in {
  options.modules.gaming = {
    enable = lib.mkEnableOption "gaming tools (Steam, Heroic, Bottles, xone)";

    steam.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Steam with Proton and game mode support.";
    };

    heroic.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install Heroic Game Launcher for Epic/GOG games.";
    };

    bottles.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install Bottles for running Windows software.";
    };

    xone.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable xone Xbox One/Series controller driver.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.steam = lib.mkIf cfg.steam.enable {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = false;
    };

    environment.systemPackages =
      lib.optional cfg.heroic.enable pkgs.heroic
      ++ lib.optional cfg.bottles.enable pkgs.bottles;

    hardware.xone.enable = cfg.xone.enable;
  };
}
