{
  config,
  lib,
  ...
}: let
  cfg = config.services.homelab.alloy;
  domain = "clips.zekurio.xyz";
  port = 3000;
  user = "alloy";
  group = "alloy";
  uid = 972;
  gid = 969;
  stateDir = "/var/lib/alloy";
  cacheDir = "/var/cache/alloy";
  storageDir = "/tank/alloy/storage";
  renderGid = config.users.groups.render.gid;
  videoGid = config.users.groups.video.gid;
in {
  options.services.homelab.alloy = {
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
      authentication = lib.mkBefore ''
        host alloy alloy 127.0.0.1/32 trust
        host alloy alloy ::1/128 trust
      '';
      ensureDatabases = ["alloy"];
      ensureUsers = [
        {
          name = user;
          ensureDBOwnership = true;
          ensureClauses.login = true;
        }
      ];
    };

    virtualisation.oci-containers.containers.alloy = {
      image = "ghcr.io/zekurio/alloy:nightly";
      pull = "newer";
      autoStart = true;
      user = "${toString uid}:${toString gid}";

      environment = {
        DATABASE_URL = "postgresql://${user}@127.0.0.1:5432/alloy";
        ALLOY_STATE_DIR = stateDir;
        ALLOY_CONFIG_FILE = "${stateDir}/config.json";
        ENCODE_SCRATCH_DIR = "${cacheDir}/scratch";
        PORT = toString port;
        PUBLIC_SERVER_URL = "https://${domain}";
        TRUSTED_ORIGINS = "https://${domain}";
      };

      volumes = [
        "${stateDir}:${stateDir}"
        "${cacheDir}:${cacheDir}"
        "/tank/alloy:/tank/alloy"
      ];

      devices = [
        "/dev/dri:/dev/dri"
      ];

      extraOptions = [
        "--network=host"
        "--group-add=${toString renderGid}"
        "--group-add=${toString videoGid}"
      ];
    };

    systemd.services.podman-alloy = {
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
      "d /tank/alloy 0700 ${user} ${group} -"
      "d ${storageDir} 0700 ${user} ${group} -"
    ];

    services.homelab.caddy.virtualHosts."alloy" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
