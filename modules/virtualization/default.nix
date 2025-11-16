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
    enable = lib.mkEnableOption "Docker virtualization stack";

    docker = {
      autoPrune = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to periodically prune unused Docker resources.";
        };
        dates = lib.mkOption {
          type = lib.types.str;
          default = "daily";
          description = "Systemd calendar specification used for Docker auto-prune.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation = {
      docker = {
        enable = true;
        autoPrune = {
          enable = cfg.docker.autoPrune.enable;
          dates = cfg.docker.autoPrune.dates;
        };
      };
      oci-containers.backend = "docker";
    };

    environment.systemPackages = with pkgs; [
      docker-compose
    ];
  };
}
