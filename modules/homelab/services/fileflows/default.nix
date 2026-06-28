{
  config,
  lib,
  ...
}: let
  cfg = config.services.homelab.fileflows;

  domain = "ff.schnitzelflix.xyz";
  port = 19200;
  shareUid = config.users.users.share.uid;
  shareGid = config.users.groups.share.gid;
  videoGid = config.users.groups.video.gid;
  renderGid = config.users.groups.render.gid;

  stateDir = "/var/lib/fileflows";
  dataDir = "${stateDir}/data";
  commonDir = "${stateDir}/common";
  logsDir = "/var/log/fileflows";
  cacheDir = "/var/cache/fileflows";
  tempDir = "${cacheDir}/temp";
in {
  options.services.homelab.fileflows = {
    enable = lib.mkEnableOption "FileFlows media automation server with Podman and Intel QSV";

    image = lib.mkOption {
      type = lib.types.str;
      default = "revenz/fileflows";
      description = "Container image to run.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.fileflows = {
      image = cfg.image;
      autoStart = true;
      ports = [
        "${toString port}:5000"
      ];
      devices = [
        "/dev/dri:/dev/dri"
      ];
      environment = {
        TZ = "Europe/Vienna";
        LIBVA_DRIVER_NAME = "iHD";
        PUID = toString shareUid;
        PGID = toString shareGid;
        TempPathHost = tempDir;
      };
      volumes = [
        "/run/docker.sock:/var/run/docker.sock:ro"
        "${tempDir}:/temp"
        "${dataDir}:/app/Data"
        "${logsDir}:/app/Logs"
        "${commonDir}:/app/common"
        "/var/lib/downloads:/var/lib/downloads"
        "/tank/media:/tank/media"
      ];
      extraOptions = [
        "--group-add=${toString videoGid}"
        "--group-add=${toString renderGid}"
        "--stop-timeout=30"
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${stateDir} 2775 share share -"
      "d ${dataDir} 2775 share share -"
      "d ${commonDir} 2775 share share -"
      "d ${logsDir} 2775 share share -"
      "d ${cacheDir} 2775 share share -"
      "d ${tempDir} 2775 share share -"
    ];

    systemd.services.podman-fileflows = {
      requires = ["podman.socket"];
      after = ["podman.socket"];
      serviceConfig.RequiresMountsFor = [
        stateDir
        logsDir
        cacheDir
        "/var/lib/downloads"
        "/tank/media"
      ];
    };

    services.homelab.caddy.virtualHosts."fileflows" = {
      inherit domain;
      forwardAuth = "127.0.0.1:4180";
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
