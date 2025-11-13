{ lib
, pkgs
, config
, ...
}:
let
  cfg = config.modules.gaming;
in
{
  options.modules.gaming = {
    enable = lib.mkEnableOption "Gaming tools and utilities";
  };

  config = lib.mkIf cfg.enable {
    programs = {
      steam = {
        enable = true;
        gamescopeSession.enable = true;
      };
      gamemode.enable = true;
    };

    environment.systemPackages = with pkgs; [
      heroic
      mangohud
      protonplus
    ];

    hardware.xone.enable = true;
  };
}
