{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.modules.gaming;
in {
  options.modules.gaming.enable = lib.mkEnableOption "gaming tools (Steam, Heroic, Bottles, MangoHud, xone)";

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };

    programs.gamemode.enable = true;

    environment.systemPackages = [
      pkgs.heroic
      pkgs.bottles
      pkgs.protonplus
    ];

    home-manager.users.zekurio.programs.mangohud.enable = true;
    home-manager.users.zekurio.home.sessionVariables.MANGOHUD = "1";

    home-manager.users.zekurio.xdg.configFile."MangoHud/MangoHud.conf".text = ''
      control=mangohud
      no_display
      full
      cpu_temp
      gpu_temp
      ram
      vram
      io_read
      io_write
      arch
      gpu_name
      cpu_power
      gpu_power
      wine
      frametime
    '';

    hardware.xone.enable = true;
  };
}
