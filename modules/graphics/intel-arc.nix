{ lib
, config
, pkgs
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.graphics.intelArc;
in
{
  options.modules.graphics.intelArc = {
    enable = mkEnableOption "Intel ARC GPU support";
  };

  config = mkIf cfg.enable {
    boot.kernelParams = [ "i915.enable_guc=3" ];
    boot.kernelModules = [ "i915" ];

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "iHD";
    };

    hardware = {
      enableAllFirmware = true;
      enableRedistributableFirmware = true;
      graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver # VA-API (iHD) userspace
          vpl-gpu-rt # oneVPL (QSV) runtime
          intel-compute-runtime # OpenCL (NEO) + Level Zero for Arc/Xe
        ];
      };
    };
  };
}
