{
  config,
  lib,
  ...
}: let
  cfg = config.services.homelab.alloy-clips;
  domain = "clips.zekurio.xyz";
  port = 3000;
  user = "alloy-clips";
  group = "alloy-clips";
  uid = 972;
  gid = 969;
  stateDir = "/var/lib/alloy-clips";
  cacheDir = "/var/cache/alloy-clips";
  storageDir = "/tank/alloy-clips/storage";
  renderGid = config.users.groups.render.gid;
  videoGid = config.users.groups.video.gid;
in {
  options.services.homelab.alloy-clips = {
    enable = lib.mkEnableOption "Alloy clip sharing server with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    users.groups.${group}.gid = gid;
    users.users.${user} = {
      inherit uid group;
      isSystemUser = true;
      extraGroups = [
        "render"
        "video"
      ];
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = ["alloy-clips"];
      ensureUsers = [
        {
          name = user;
          ensureDBOwnership = true;
          ensureClauses.login = true;
        }
      ];
    };

    virtualisation.oci-containers.containers.alloy-clips = {
      image = "ghcr.io/zekurio/alloy-server:unstable";
      pull = "newer";
      autoStart = true;
      user = "${toString uid}:${toString gid}";

      environment = {
        DATABASE_URL = "postgresql:///alloy-clips";
        PGHOST = "/run/postgresql";
        PGPORT = "5432";
        PGUSER = user;
        ALLOY_STATE_DIR = stateDir;
        ALLOY_CONFIG_FILE = "${stateDir}/config.json";
        ENCODE_SCRATCH_DIR = "${cacheDir}/scratch";
        PORT = toString port;
        PUBLIC_SERVER_URL = "https://${domain}";
        TRUSTED_ORIGINS = "https://${domain}";
      };

      ports = [
        "127.0.0.1:${toString port}:${toString port}"
      ];

      volumes = [
        "${stateDir}:${stateDir}"
        "${cacheDir}:${cacheDir}"
        "/tank/alloy-clips:/tank/alloy-clips"
        "/run/postgresql:/run/postgresql"
      ];

      devices = [
        "/dev/dri:/dev/dri"
      ];

      extraOptions = [
        "--group-add=${toString renderGid}"
        "--group-add=${toString videoGid}"
      ];
    };

    systemd.services.podman-alloy-clips = {
      requires = [
        "postgresql.service"
        "tank-datasets.service"
      ];
      after = [
        "postgresql.service"
        "postgresql-setup.service"
        "tank-datasets.service"
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0700 ${user} ${group} -"
      "d ${stateDir}/data 0700 ${user} ${group} -"
      "d ${stateDir}/data/storage 0700 ${user} ${group} -"
      "d ${cacheDir} 0700 ${user} ${group} -"
      "d ${cacheDir}/scratch 0700 ${user} ${group} -"
      "d /tank/alloy-clips 0700 ${user} ${group} -"
      "d ${storageDir} 0700 ${user} ${group} -"
    ];

    services.homelab.caddy.virtualHosts."alloy-clips" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
