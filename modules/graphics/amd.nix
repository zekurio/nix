{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.graphics.amd;
in {
  options.modules.graphics.amd = {
    enable = mkEnableOption "AMD GPU support";
  };

  config = mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
    environment.systemPackages = with pkgs; [lact];
    systemd.packages = with pkgs; [lact];
    systemd.services.lactd.wantedBy = ["multi-user.target"];
    environment.variables.AMD_VULKAN_ICD = "RADV";
    hardware.firmware = with pkgs; [linux-firmware];
  };
}
