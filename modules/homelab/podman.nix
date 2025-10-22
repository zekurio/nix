{ config, lib, ... }:

with lib;

let
  cfg = config.virtualisation.podman-homelab;
  mediaGroup = "media";
  mediaUser = "zekurio";
  mediaUid = attrByPath [ "users" "users" mediaUser "uid" ] 1000 config;
  mediaGid = attrByPath [ "users" "groups" mediaGroup "gid" ] 991 config;
  mediaUidStr = toString mediaUid;
  mediaGidStr = toString mediaGid;
in
{
  options.virtualisation.podman-homelab = {
    enable = mkEnableOption "Podman homelab containers";

    jellyfin = {
      enable = mkEnableOption "Jellyfin container" // { default = true; };
      port = mkOption {
        type = types.port;
        default = 8096;
        description = "Port for Jellyfin web interface";
      };
    };

    fileflows = {
      enable = mkEnableOption "FileFlows container" // { default = true; };
      port = mkOption {
        type = types.port;
        default = 19200;
        description = "Port for FileFlows web interface";
      };
    };

    configarr = {
      enable = mkEnableOption "Configarr container" // { default = false; };
    };
  };

  config = mkIf cfg.enable {
    # Enable Podman
    virtualisation = {
      containers.enable = true;
      podman = {
        enable = true;
        dockerCompat = true;
        autoPrune.enable = true;
        defaultNetwork.settings = {
          dns_enabled = true;
        };
      };
      oci-containers.backend = "podman";
    };

    # Container definitions
    virtualisation.oci-containers.containers = mkMerge [
      (mkIf cfg.jellyfin.enable {
        jellyfin = {
          image = "ghcr.io/jellyfin/jellyfin:latest";
          autoStart = true;
          user = "1000:1000";
          ports = [ "${toString cfg.jellyfin.port}:8096" ];

          volumes = [
            "/mnt/fast-nvme/media:/media"
            "/var/lib/containers/jellyfin:/config"
            "/var/cache/containers/jellyfin:/cache"
          ];

          extraOptions = [
            "--device=/dev/dri:/dev/dri"
          ];
        };
      })

      (mkIf cfg.fileflows.enable {
        fileflows = {
          image = "revenz/fileflows:latest";
          autoStart = true;
          ports = [ "${toString cfg.fileflows.port}:5000" ];
          user = "${mediaUidStr}:${mediaGidStr}";

          volumes = [
            "/run/podman/podman.sock:/var/run/docker.sock:ro"
            "/var/downloads:/downloads"
            "/var/lib/containers/fileflows/data:/app/Data"
            "/var/lib/containers/fileflows/logs:/app/Logs"
            "/tmp/fileflows:/temp"
          ];

          environment = {
            TempPathHost = "/tmp/fileflows";
            PUID = mediaUidStr;
            PGID = mediaGidStr;
            UMASK = "0002";
          };

          extraOptions = [
            "--device=/dev/dri:/dev/dri"
          ];
        };
      })

      (mkIf cfg.configarr.enable {
        configarr = {
          image = "ghcr.io/raydak-labs/configarr:latest";
          autoStart = false;
          user = "1000:1000";

          volumes = [
            "/var/lib/containers/configarr/config:/app/config"
            "/var/lib/containers/configarr/repos:/app/repos"
          ];
        };
      })
    ];

    # Create required directories for containers
    systemd.tmpfiles.rules = mkIf cfg.enable [
      # Podman directories
      "d /var/lib/containers/jellyfin 2775 ${mediaUser} ${mediaGroup} -"
      "d /var/cache/containers/jellyfin 2775 ${mediaUser} ${mediaGroup} -"
      "d /var/lib/containers/fileflows/data 2775 ${mediaUser} ${mediaGroup} -"
      "d /var/lib/containers/fileflows/logs 2775 ${mediaUser} ${mediaGroup} -"
      "d /tmp/fileflows 2775 ${mediaUser} ${mediaGroup} -"
      "d /var/lib/containers/configarr/config 2775 ${mediaUser} ${mediaGroup} -"
      "d /var/lib/containers/configarr/repos 2775 ${mediaUser} ${mediaGroup} -"
    ];
  };
}
