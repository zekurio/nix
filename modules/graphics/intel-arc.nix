{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.graphics.intelArc;
in {
  options.modules.graphics.intelArc = {
    enable = mkEnableOption "Intel ARC GPU support";
  };

  config = mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver   # iHD VA-API (required)
        vpl-gpu-rt           # oneVPL/QSV
        intel-compute-runtime # OpenCL/Level Zero (optional but useful)
        intel-graphics-compiler
        level-zero
        ocl-icd
        libva-utils
      ];
      extraPackages32 = with pkgs; [
        intel-media-driver
      ];
    };

    environment.variables.LIBVA_DRIVER_NAME = "iHD";

    systemd.services.jellyfin.serviceConfig.Environment = [
      "LIBVA_DRIVER_NAME=iHD"
    ];
  };
}
