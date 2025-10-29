{ lib
, config
, pkgs
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.graphics.nvidia;
in
{
  options.modules.graphics.nvidia = {
    enable = mkEnableOption "NVIDIA GPU support";
  };

  config = mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
      ];
    };

    services.xserver.videoDrivers = lib.mkDefault [ "nvidia" ];

    hardware.nvidia = {
      package = lib.mkDefault config.boot.kernelPackages.nvidiaPackages.production;
      modesetting.enable = true;
      powerManagement.enable = lib.mkDefault true;
      powerManagement.finegrained = lib.mkDefault false;
      nvidiaSettings = true;
      nvidiaPersistenced = true;
      open = lib.mkDefault false;
    };
  };
}
