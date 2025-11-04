{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.virtualisation.podman-homelab;
  shareGroup = "share";
  shareUser = "share";
  shareUid = attrByPath ["users" "users" shareUser "uid"] 995 config;
  shareGid = attrByPath ["users" "groups" shareGroup "gid"] 995 config;
  shareUidStr = toString shareUid;
  shareGidStr = toString shareGid;
in {
  options.virtualisation.podman-homelab = {
    enable = mkEnableOption "Podman homelab containers";

    fileflows = {
      enable = mkEnableOption "FileFlows container" // {default = true;};
      port = mkOption {
        type = types.port;
        default = 19200;
        description = "Port for FileFlows web interface";
      };
    };

    configarr = {
      enable = mkEnableOption "Configarr container" // {default = false;};
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
      (mkIf cfg.fileflows.enable {
        fileflows = {
          image = "revenz/fileflows:latest";
          autoStart = true;
          ports = ["${toString cfg.fileflows.port}:5000"];

          volumes = [
            "/run/podman/podman.sock:/var/run/docker.sock:ro"
            "/var/downloads:/downloads"
            "/mnt/fast-nvme/media:/media"
            "/var/lib/fileflows/data:/app/Data"
            "/var/lib/fileflows/logs:/app/Logs"
            "/tmp/fileflows:/temp"
          ];

          environment = {
            TempPathHost = "/tmp/fileflows";
            PUID = shareUidStr;
            PGID = shareGidStr;
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
          user = "${shareUidStr}:${shareGidStr}";

          volumes = [
            "/var/lib/configarr/config:/app/config"
            "/var/lib/configarr/repos:/app/repos"
          ];
        };
      })
    ];

    # Create required directories for containers
    systemd.tmpfiles.rules = mkIf cfg.enable [
      # Podman directories
      "d /var/lib/fileflows/data 2775 ${shareUser} ${shareGroup} -"
      "d /var/lib/fileflows/logs 2775 ${shareUser} ${shareGroup} -"
      "d /tmp/fileflows 2775 ${shareUser} ${shareGroup} -"
      "d /var/lib/configarr/config 2775 ${shareUser} ${shareGroup} -"
      "d /var/lib/configarr/repos 2775 ${shareUser} ${shareGroup} -"
    ];
  };
}
