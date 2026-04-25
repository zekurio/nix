{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.alloy;
  dataDir = "/var/lib/alloy";
  runtimeDir = "/run/alloy";
  serverRuntimeEnv = "${runtimeDir}/server.env";
  webRuntimeEnv = "${runtimeDir}/web.env";
  databaseUrl = "postgresql://alloy@127.0.0.1:5432/alloy";
  sanitizeEnvFile = pkgs.writeShellScript "alloy-sanitize-env-file" ''
    set -eu

    src="$1"
    dest="$2"
    shift 2

    tmp="$(${pkgs.coreutils}/bin/mktemp)"
    trap 'rm -f "$tmp"' EXIT

    ${pkgs.gawk}/bin/awk '
      /^[[:space:]]*($|#)/ { next }
      {
        line = $0
        sub(/\r$/, "", line)
        eq = index(line, "=")
        if (!eq) next

        key = substr(line, 1, eq - 1)
        value = substr(line, eq + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)

        if (value ~ /^".*"$/) {
          value = substr(value, 2, length(value) - 2)
        }

        if (key ~ /^[A-Za-z_][A-Za-z0-9_]*$/) {
          print key "=" value
        }
      }
    ' "$src" > "$tmp"

    for assignment in "$@"; do
      printf '%s\n' "$assignment" >> "$tmp"
    done

    ${pkgs.coreutils}/bin/install -D -m 0600 "$tmp" "$dest"
  '';
in {
  options.services.homelab.alloy = {
    enable = lib.mkEnableOption "Alloy clip sharing service with Caddy integration";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "clips.zekurio.xyz";
      description = "Public domain served by Caddy for Alloy.";
    };

    serverImage = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/zekurio/alloy-server:unstable";
      description = "Container image for the Alloy API server.";
    };

    webImage = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/zekurio/alloy-web:unstable";
      description = "Container image for the Alloy web app.";
    };

    serverPort = lib.mkOption {
      type = lib.types.port;
      default = 3010;
      description = "Host port used by the Alloy API server container.";
    };

    webPort = lib.mkOption {
      type = lib.types.port;
      default = 3020;
      description = "Host port used by the Alloy web container.";
    };

    serverEnvironmentFile = lib.mkOption {
      type = lib.types.str;
      default = "/home/zekurio/Git/alloy/apps/server/.env.prod";
      description = "Environment file for the Alloy API server container.";
    };

    webEnvironmentFile = lib.mkOption {
      type = lib.types.str;
      default = "/home/zekurio/Git/alloy/apps/web/.env.prod";
      description = "Environment file for the Alloy web container.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      enableTCPIP = true;
      ensureDatabases = ["alloy"];
      ensureUsers = [
        {
          name = "alloy";
          ensureDBOwnership = true;
        }
      ];
      authentication = lib.mkAfter ''
        host alloy alloy 127.0.0.1/32 trust
      '';
    };

    systemd.tmpfiles.rules = [
      "d ${dataDir} 0755 root root -"
      "d ${dataDir}/data 0755 root root -"
      "d ${dataDir}/data/storage 0755 root root -"
      "d ${dataDir}/data/encode 0755 root root -"
    ];

    systemd.services.alloy-db-migrate = {
      description = "Run Alloy database migrations";
      after = ["postgresql.service" "podman.service"];
      requires = ["postgresql.service"];
      before = ["podman-alloy-server.service" "podman-alloy-web.service"];
      wantedBy = ["multi-user.target"];
      path = [pkgs.podman];
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        ${sanitizeEnvFile} ${lib.escapeShellArg cfg.serverEnvironmentFile} ${serverRuntimeEnv} \
          DATABASE_URL=${lib.escapeShellArg databaseUrl} \
          BETTER_AUTH_URL=https://${lib.escapeShellArg cfg.domain} \
          TRUSTED_ORIGINS=https://${lib.escapeShellArg cfg.domain} \
          PORT=${toString cfg.serverPort} \
          RUNTIME_CONFIG_PATH=/data/runtime-config.json \
          STORAGE_FS_ROOT=/data/storage \
          ENCODE_SCRATCH_DIR=/data/encode

        podman pull ${lib.escapeShellArg cfg.serverImage}
        podman run --rm \
          --network=host \
          --env-file ${serverRuntimeEnv} \
          -v ${lib.escapeShellArg "${dataDir}/data"}:/data \
          ${lib.escapeShellArg cfg.serverImage} \
          pnpm --dir /app/packages/db migrate:deploy
      '';
    };

    virtualisation.oci-containers.containers = {
      alloy-server = {
        image = cfg.serverImage;
        autoStart = true;
        dependsOn = [];
        extraOptions = ["--network=host"];
        environment = {
          DATABASE_URL = databaseUrl;
          PORT = toString cfg.serverPort;
          BETTER_AUTH_URL = "https://${cfg.domain}";
          TRUSTED_ORIGINS = "https://${cfg.domain}";
          RUNTIME_CONFIG_PATH = "/data/runtime-config.json";
          STORAGE_FS_ROOT = "/data/storage";
          ENCODE_SCRATCH_DIR = "/data/encode";
        };
        environmentFiles = [serverRuntimeEnv];
        volumes = [
          "${dataDir}/data:/data"
        ];
      };

      alloy-web = {
        image = cfg.webImage;
        autoStart = true;
        extraOptions = ["--network=host"];
        environment = {
          INTERNAL_API_URL = "http://127.0.0.1:${toString cfg.serverPort}";
          PORT = toString cfg.webPort;
          PUBLIC_APP_URL = "https://${cfg.domain}";
          PUBLIC_API_URL = "https://${cfg.domain}";
          VITE_API_URL = "https://${cfg.domain}/api";
        };
        environmentFiles = [webRuntimeEnv];
      };
    };

    systemd.services.podman-alloy-server = {
      after = ["alloy-db-migrate.service"];
      requires = ["alloy-db-migrate.service"];
      preStart = ''
        ${sanitizeEnvFile} ${lib.escapeShellArg cfg.serverEnvironmentFile} ${serverRuntimeEnv} \
          DATABASE_URL=${lib.escapeShellArg databaseUrl} \
          BETTER_AUTH_URL=https://${lib.escapeShellArg cfg.domain} \
          TRUSTED_ORIGINS=https://${lib.escapeShellArg cfg.domain} \
          PORT=${toString cfg.serverPort} \
          RUNTIME_CONFIG_PATH=/data/runtime-config.json \
          STORAGE_FS_ROOT=/data/storage \
          ENCODE_SCRATCH_DIR=/data/encode
      '';
    };

    systemd.services.podman-alloy-web = {
      after = ["podman-alloy-server.service"];
      requires = ["podman-alloy-server.service"];
      preStart = ''
        ${sanitizeEnvFile} ${lib.escapeShellArg cfg.webEnvironmentFile} ${webRuntimeEnv} \
          INTERNAL_API_URL=http://127.0.0.1:${toString cfg.serverPort} \
          PORT=${toString cfg.webPort} \
          PUBLIC_APP_URL=https://${lib.escapeShellArg cfg.domain} \
          PUBLIC_API_URL=https://${lib.escapeShellArg cfg.domain} \
          VITE_API_URL=https://${lib.escapeShellArg cfg.domain}/api
      '';
    };

    services.homelab.caddy.virtualHosts."alloy" = {
      domain = cfg.domain;
      reverseProxy = "127.0.0.1:${toString cfg.webPort}";
    };
  };
}
