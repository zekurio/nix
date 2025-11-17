{ lib
, config
, pkgs
, ...
}:
let
  cfg = config.modules.virtualization;
in
{
  options.modules.virtualization = {
    enable = lib.mkEnableOption "Rootless Podman virtualization stack";

    podman = {
      autoPrune = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to periodically prune unused Podman resources.";
        };
        dates = lib.mkOption {
          type = lib.types.str;
          default = "daily";
          description = "Systemd calendar specification used for Podman auto-prune.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation = {
      podman = {
        enable = true;
        autoPrune = {
          enable = cfg.podman.autoPrune.enable;
          dates = cfg.podman.autoPrune.dates;
        };
      };
      oci-containers.backend = "podman";
    };

    environment.systemPackages = with pkgs; [
      podman-compose
    ];
  };
}
