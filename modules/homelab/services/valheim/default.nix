{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.valheim;
    dataDir = "/var/lib/valheim";
    unit = "${config.virtualisation.oci-containers.backend}-valheim.service";
  in {
    options.services.homelab.valheim = {
      enable = lib.mkEnableOption "Valheim dedicated server with Valheim Plus";

      image = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/community-valheim-tools/valheim-server:latest";
        description = "Container image to run.";
      };

      serverName = lib.mkOption {
        type = lib.types.str;
        default = "zekurio's Valheim server";
        description = "Display name shown to players.";
      };

      worldName = lib.mkOption {
        type = lib.types.str;
        default = "Midgard";
        description = "Persistent world name. Changing this selects a different world.";
      };

      public = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to list the server in the community server browser.";
      };

      extraEnvironment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        example = {VPCFG_Player_baseMaximumWeight = "450";};
        description = "Additional non-secret container settings, including VPCFG overrides.";
      };
    };

    config = lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.valheim = {
        image = cfg.image;
        autoStart = true;
        extraOptions = ["--stop-timeout=120"];
        environment =
          {
            PUID = "1000";
            PGID = "1000";
            TZ = config.time.timeZone;
            SERVER_NAME = cfg.serverName;
            WORLD_NAME = cfg.worldName;
            SERVER_PUBLIC = lib.boolToString cfg.public;
            SERVER_PORT = "2456";
            CROSSPLAY = "false";
            VALHEIM_PLUS = "true";
            VALHEIM_PLUS_REPO = "Grantapher/ValheimPlus";
            VPCFG_Server_enabled = "true";
            VPCFG_Server_enforceMod = "true";
            VPCFG_Server_serverSyncsConfig = "true";
            UPDATE_CRON = "0 6 * * *";
            UPDATE_IF_IDLE = "true";
            BACKUPS = "true";
            BACKUPS_CRON = "5 * * * *";
            BACKUPS_MAX_AGE = "7";
          }
          // cfg.extraEnvironment;
        environmentFiles = [config.sops.templates."valheim.env".path];
        # Some mod RPCs use game port + 2 in addition to the game/query ports.
        ports = ["2456-2458:2456-2458/udp"];
        volumes = [
          "${dataDir}/config:/config"
          "${dataDir}/data:/opt/valheim"
        ];
      };

      systemd.tmpfiles.rules = [
        "d ${dataDir} 0750 1000 1000 -"
        "d ${dataDir}/config 0750 1000 1000 -"
        "d ${dataDir}/data 0750 1000 1000 -"
      ];
      systemd.services.${lib.removeSuffix ".service" unit} = {
        # Remove both copies so persisted plugin files cannot reload RecyclePlus.
        preStart = lib.mkBefore ''
          ${pkgs.coreutils}/bin/rm -f \
            ${dataDir}/config/valheimplus/plugins/RecyclePlus.dll \
            ${dataDir}/data/plus/BepInEx/plugins/RecyclePlus.dll
        '';
        # Allow the container's two-minute world-save grace period to finish.
        serviceConfig.TimeoutStopSec = lib.mkForce 150;
      };

      # Valheim uses UDP directly, so it does not have an HTTP Caddy vhost.
      networking.firewall.allowedUDPPorts = [2456 2457 2458];

      sops.secrets.valheim_password = {};
      sops.templates."valheim.env" = {
        content = ''
          SERVER_PASS=${config.sops.placeholder.valheim_password}
        '';
        restartUnits = [unit];
      };
    };
  };
}
