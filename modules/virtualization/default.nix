{
  lib,
  config,
  ...
}: let
  cfg = config.modules.virtualization;
in {
  options.modules.virtualization = {
    enable = lib.mkEnableOption "Podman virtualization stack";

    podman = {
      dockerCompat = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable docker-compatible socket for Podman";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation = {
      podman = {
        enable = true;
        dockerCompat = cfg.podman.dockerCompat;
      };
      oci-containers.backend = "podman";
    };
  };
}
