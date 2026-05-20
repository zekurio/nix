{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.kyoo;

  domain = "preview.schnitzelflix.xyz";
  publicUrl = "https://${domain}";
  dataDir = "/var/lib/kyoo";
  cacheDir = "/var/cache/kyoo";
  network = "kyoo";

  containerNames = [
    "kyoo-auth"
    "kyoo-api"
    "kyoo-front"
    "kyoo-scanner"
    "kyoo-transcoder"
    "kyoo-traefik"
  ];

  oidcEnvironment = {
    OIDC_POCKETID_NAME = "Pocket ID";
    OIDC_POCKETID_AUTHORIZATION = "https://auth.zekurio.me/authorize";
    OIDC_POCKETID_TOKEN = "https://auth.zekurio.me/api/oidc/token";
    OIDC_POCKETID_PROFILE = "https://auth.zekurio.me/api/oidc/userinfo";
    OIDC_POCKETID_SCOPE = "email openid profile";
    OIDC_POCKETID_AUTHMETHOD = "ClientSecretPost";
  };

  commonEnvironment =
    {
      PUBLIC_URL = publicUrl;
      LIBRARY_ROOT = "/video";
      CACHE_ROOT = "/cache";
      IMAGES_PATH = "/images";
      LIBRARY_IGNORE_PATTERN = ".*/[dD]ownloads?/.*";
      COMPOSE_PROFILES = cfg.hardwareAcceleration;
      GOCODER_PRESET = "fast";
      EXTRA_CLAIMS = ''{"permissions": ["core.read", "core.play"], "verified": false}'';
      FIRST_USER_CLAIMS = ''{"permissions": ["users.read", "users.write", "users.delete", "apikeys.read", "apikeys.write", "core.read", "core.write", "core.play", "scanner.trigger", "scanner.guess", "scanner.search", "scanner.add"], "verified": true}'';
      GUEST_CLAIMS = "";
      PROTECTED_CLAIMS = "permissions,verified";
      KEIBI_APIKEY_SCANNER_CLAIMS = ''{"permissions": ["core.read", "core.write"]}'';
      OTEL_EXPORTER_OTLP_ENDPOINT = "http://localhost:4317";
      OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf";
      PGUSER = "kyoo";
      PGDATABASE = "kyoo";
      PGHOST = "/run/postgresql";
      PGPORT = "5432";
    }
    // oidcEnvironment;

  envFiles = [config.sops.secrets.kyoo_env.path];
  postgresSocketVolume = "/run/postgresql:/run/postgresql";

  networkOptions = alias: [
    "--network=${network}"
    "--network-alias=${alias}"
  ];

  traefikLabels = {
    "traefik.enable" = "true";
  };

  phantomTokenLabels = {
    "traefik.http.middlewares.phantom-token.forwardauth.address" = "http://auth:4568/auth/jwt";
    "traefik.http.middlewares.phantom-token.forwardauth.authRequestHeaders" = "Authorization,Cookie,X-Api-Key,Sec-WebSocket-Protocol";
    "traefik.http.middlewares.phantom-token.forwardauth.authResponseHeaders" = "Authorization";
  };

  mkContainer = alias: extra:
    {
      autoStart = true;
      environmentFiles = envFiles;
      extraOptions = networkOptions alias;
    }
    // extra;
in {
  options.services.homelab.kyoo = {
    enable = lib.mkEnableOption "Kyoo media server preview with Caddy integration";

    hardwareAcceleration = lib.mkOption {
      type = lib.types.enum [
        "cpu"
        "vaapi"
        "qsv"
      ];
      default = "qsv";
      description = "Transcoder hardware acceleration profile.";
    };

    mediaPath = lib.mkOption {
      type = lib.types.path;
      default = /tank/media;
      description = "Media library path mounted read-only into Kyoo.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8901;
      description = "Local Traefik port exposed for Caddy.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.hardwareAcceleration != "qsv" || config.hardware.graphics.enable;
        message = "Kyoo qsv acceleration expects hardware.graphics.enable for /dev/dri support.";
      }
    ];

    virtualisation.oci-containers.containers = {
      kyoo-auth = mkContainer "auth" {
        image = "ghcr.io/zoriya/kyoo_auth:5.0";
        environment = commonEnvironment;
        volumes = [
          postgresSocketVolume
          "${dataDir}/profile_pictures:/profile_pictures"
        ];
        labels =
          traefikLabels
          // {
            "traefik.http.routers.auth.rule" = "PathPrefix(`/auth/`) || PathPrefix(`/.well-known/`)";
          };
      };

      kyoo-api = mkContainer "api" {
        image = "ghcr.io/zoriya/kyoo_api:5.0";
        dependsOn = ["kyoo-auth"];
        environment =
          commonEnvironment
          // {
            JWT_ISSUER = publicUrl;
          };
        volumes = [
          postgresSocketVolume
          "${dataDir}/images:/images"
        ];
        labels =
          traefikLabels
          // phantomTokenLabels
          // {
            "traefik.http.routers.swagger.rule" = "PathPrefix(`/swagger`)";
            "traefik.http.routers.api.rule" = "PathPrefix(`/api/`)";
            "traefik.http.routers.api.middlewares" = "phantom-token";
          };
      };

      kyoo-front = mkContainer "front" {
        image = "ghcr.io/zoriya/kyoo_front:5.0";
        environment = {
          KYOO_URL = "http://api:5000/api";
        };
        labels =
          traefikLabels
          // {
            "traefik.http.routers.front.rule" = "PathPrefix(`/`)";
            "traefik.http.services.front.loadbalancer.server.port" = "8901";
          };
      };

      kyoo-scanner = mkContainer "scanner" {
        image = "ghcr.io/zoriya/kyoo_scanner:5.0";
        dependsOn = ["kyoo-api" "kyoo-auth"];
        environment =
          commonEnvironment
          // {
            KYOO_URL = "http://traefik:8901/api";
            JWKS_URL = "http://auth:4568/.well-known/jwks.json";
            JWT_ISSUER = publicUrl;
          };
        volumes = [
          postgresSocketVolume
          "${toString cfg.mediaPath}:/video:ro"
        ];
        labels =
          traefikLabels
          // phantomTokenLabels
          // {
            "traefik.http.routers.scanner.rule" = "PathPrefix(`/scanner/`)";
            "traefik.http.routers.scanner.middlewares" = "phantom-token";
          };
      };

      kyoo-transcoder = mkContainer "transcoder" {
        image = "ghcr.io/zoriya/kyoo_transcoder:5.0";
        dependsOn = ["kyoo-auth"];
        environment =
          commonEnvironment
          // {
            JWKS_URL = "http://auth:4568/.well-known/jwks.json";
          }
          // lib.optionalAttrs (cfg.hardwareAcceleration != "cpu") {
            GOCODER_HWACCEL = cfg.hardwareAcceleration;
            GOCODER_VAAPI_RENDERER = "/dev/dri/renderD128";
          };
        devices = lib.optionals (cfg.hardwareAcceleration != "cpu") [
          "/dev/dri:/dev/dri"
        ];
        volumes = [
          postgresSocketVolume
          "${toString cfg.mediaPath}:/video:ro"
          "${cacheDir}:/cache"
          "${dataDir}/transcoder_metadata:/metadata"
        ];
        labels =
          traefikLabels
          // phantomTokenLabels
          // {
            "traefik.http.routers.transcoder.rule" = "PathPrefix(`/video`)";
            "traefik.http.routers.transcoder.middlewares" = "phantom-token";
          };
      };

      kyoo-traefik = mkContainer "traefik" {
        image = "docker.io/library/traefik:v3.6";
        dependsOn = [
          "kyoo-auth"
          "kyoo-api"
          "kyoo-front"
          "kyoo-scanner"
          "kyoo-transcoder"
        ];
        cmd = [
          "--providers.docker=true"
          "--providers.docker.exposedbydefault=false"
          "--entryPoints.web.address=:8901"
          "--accesslog=true"
        ];
        ports = [
          "127.0.0.1:${toString cfg.port}:8901"
        ];
        volumes = [
          "/run/podman/podman.sock:/var/run/docker.sock:ro"
        ];
      };
    };

    systemd.services =
      {
        podman-network-kyoo = {
          description = "Create the Kyoo Podman network";
          wantedBy = ["multi-user.target"];
          before = map (name: "podman-${name}.service") containerNames;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [pkgs.podman];
          script = ''
            podman network exists ${lib.escapeShellArg network} || podman network create ${lib.escapeShellArg network}
          '';
        };
        postgresql-setup.serviceConfig.ExecStartPost = [
          ''
            ${lib.getExe' config.services.postgresql.package "psql"} -d kyoo -c 'CREATE EXTENSION IF NOT EXISTS pg_trgm;'
          ''
        ];
      }
      // lib.genAttrs (map (name: "podman-${name}") containerNames) (_: {
        after = [
          "podman-network-kyoo.service"
          "postgresql.target"
        ];
        requires = [
          "podman-network-kyoo.service"
          "postgresql.target"
        ];
      });

    services.postgresql = {
      enable = true;
      ensureDatabases = ["kyoo"];
      ensureUsers = [
        {
          name = "kyoo";
          ensureDBOwnership = true;
          ensureClauses.login = true;
        }
      ];
      authentication = lib.mkBefore ''
        local kyoo kyoo trust
      '';
    };

    systemd.tmpfiles.rules = [
      "d ${dataDir} 0755 root root -"
      "d ${dataDir}/images 0755 root root -"
      "d ${dataDir}/profile_pictures 0755 root root -"
      "d ${dataDir}/transcoder_metadata 0755 root root -"
      "d ${cacheDir} 0755 root root -"
    ];

    sops.secrets.kyoo_env = {
      mode = "0400";
    };

    services.homelab.caddy.virtualHosts."kyoo" = {
      domain = domain;
      reverseProxy = "127.0.0.1:${toString cfg.port}";
    };
  };
}
