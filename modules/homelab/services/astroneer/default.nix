{
  config,
  lib,
  ...
}: let
  cfg = config.services.homelab.astroneer;
in {
  options.services.homelab.astroneer = {
    enable = lib.mkEnableOption "Astroneer dedicated server container";

    port = lib.mkOption {
      type = lib.types.port;
      default = 7777;
      description = "UDP port exposed by the Astroneer dedicated server.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/astroneer";
      description = "Host directory used for persistent Astroneer server data.";
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable debug logging inside the Astroneer container.";
    };

    disableEncryption = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Disable network encryption for the Astroneer server.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.astroneer = {
      image = "docker.io/whalybird/astroneer-server:latest";
      ports = ["${toString cfg.port}:${toString cfg.port}/udp"];
      environment = {
        CREATE_LAUNCHER_CONFIG = "true";
        DEBUG = lib.boolToString cfg.debug;
        DISABLE_ENCRYPTION = lib.boolToString cfg.disableEncryption;
        TZ = "Europe/Vienna";
      };
      volumes = [
        "${cfg.stateDir}/saved:/astrotux/AstroneerServer/Astro/Saved"
      ];
      extraOptions = [
        "--pull=newer"
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0755 root root -"
      "d ${cfg.stateDir}/saved 0755 root root -"
    ];

    networking.firewall.allowedUDPPorts = [cfg.port];
  };
}
