{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.hm.gaming;
in {
  options.modules.hm.gaming = {
    enable = lib.mkEnableOption "gaming configuration";
  };

  config = lib.mkIf cfg.enable {
    # mangohud configuration
    xdg.configFile."MangoHud/MangoHud.conf".text = ''
      control=mangohud
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

    home.packages = with pkgs; [
      heroic
      mangohud
      protonplus
    ];
  };
}
