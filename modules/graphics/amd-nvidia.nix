{ lib
, config
, ...
}:
let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.modules.graphics.amdNvidia;
in
{
  options.modules.graphics.amdNvidia = {
    enable = mkEnableOption "Hybrid AMD + NVIDIA PRIME graphics support";

    primeMode = mkOption {
      type = types.enum [ "offload" "sync" ];
      default = "offload";
      description = ''
        PRIME render mode to use. Offload keeps the AMD iGPU as the primary display controller and renders on the NVIDIA dGPU on demand, while sync drives the display through the dGPU.
      '';
      example = "offload";
    };

    amdgpuBusId = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        PCI bus ID for the integrated AMD GPU. Use `lspci` to discover the identifier (e.g. `PCI:5:0:0`).
      '';
      example = "PCI:5:0:0";
    };

    nvidiaBusId = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        PCI bus ID for the NVIDIA GPU. Use `lspci | grep -i nvidia` to locate the device (e.g. `PCI:1:0:0`).
      '';
      example = "PCI:1:0:0";
    };
  };

  config = mkIf cfg.enable {
    modules.graphics.amd.enable = lib.mkDefault true;
    modules.graphics.nvidia.enable = lib.mkDefault true;

    hardware.nvidia.prime = {
      amdgpuBusId = cfg.amdgpuBusId;
      nvidiaBusId = cfg.nvidiaBusId;
      offload.enable = cfg.primeMode == "offload";
      sync.enable = cfg.primeMode == "sync";
    };

    environment.variables = {
      LIBVA_DRIVER_NAME = lib.mkDefault "radeonsi";
      VDPAU_DRIVER = lib.mkDefault "radeonsi";
    };
  };
}
