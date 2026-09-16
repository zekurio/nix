{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.fluxer;
    domain = "chat.${config.services.homelab.domains.zekurio}";
    edgePort = 8080;
    projectDir = "/var/lib/fluxer";

    # Fluxer ships only as a Compose stack, so the upstream files are pinned
    # and run as-is behind the homelab Caddy. Bump the ref, the hashes and
    # the image tag together to upgrade.
    stackRef = "34b6ecfbd27f29f2a7b9637ea7685e67e0582b85";
    imageTag = "v1";

    stackFile = name: hash:
      pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/fluxerapp/fluxer/${stackRef}/deploy/self-hosting/${name}";
        inherit hash;
      };

    composeFiles = [
      (stackFile "docker-compose.yml" "sha256-7XUZNwsyFt6CeHpZWtWnuOoSOyfJ/g+xFgFKISA11mQ=")
      # The proxy overlay makes the edge serve plain HTTP on FLUXER_EDGE_BIND
      # instead of binding 80/443, which the homelab Caddy already owns.
      (stackFile "docker-compose.proxy.yml" "sha256-RSmFjPBPF7bFBQTWEHsoTVP3AZZlf4OoULqxpnA+YmQ=")
    ];
    caddyfile = stackFile "Caddyfile" "sha256-6asaetmSERcvaM+icovuuG3U7SIGNcq1+EYbsrScsCM=";

    compose = "${lib.getExe pkgs.docker-compose} -f docker-compose.yml -f docker-compose.proxy.yml";
  in {
    options.services.homelab.fluxer = {
      enable = lib.mkEnableOption "Fluxer chat stack (Compose) with Caddy integration";
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.virtualisation.podman.dockerSocket.enable;
          message = "services.homelab.fluxer needs the Podman Docker socket (modules.virtualization.enable).";
        }
      ];

      # One secret per CHANGE_ME in upstream's .env.example. Formats must match
      # what the services parse: upload relay secret is base64, the VAPID pair
      # is a real P-256 keypair, everything else is hex.
      sops.secrets = {
        fluxer_postgres_password = {};
        fluxer_meili_master_key = {};
        fluxer_s3_secret_key = {};
        fluxer_sudo_mode_secret = {};
        fluxer_connection_initiation_secret = {};
        fluxer_gateway_rpc_auth_token = {};
        fluxer_erlang_cookie = {};
        fluxer_media_proxy_secret_key = {};
        fluxer_media_proxy_upload_relay_secret_base64 = {};
        fluxer_admin_secret_key_base = {};
        fluxer_admin_oauth_client_secret = {};
        fluxer_livekit_api_secret = {};
        fluxer_vapid_public_key = {};
        fluxer_vapid_private_key = {};
      };

      # Compose reads .env from the project directory; the fluxer unit links
      # this rendered template to ${projectDir}/.env.
      sops.templates."fluxer.env" = {
        content = ''
          FLUXER_DOMAIN=${domain}
          FLUXER_PUBLIC_SCHEME=https
          FLUXER_PUBLIC_PORT=443
          FLUXER_IMAGE_TAG=${imageTag}
          FLUXER_S3_ACCESS_KEY=fluxer
          LIVEKIT_API_KEY=fluxer
          COMPOSE_FILE=docker-compose.yml:docker-compose.proxy.yml
          FLUXER_EDGE_BIND=127.0.0.1:${toString edgePort}
          POSTGRES_PASSWORD=${config.sops.placeholder.fluxer_postgres_password}
          MEILI_MASTER_KEY=${config.sops.placeholder.fluxer_meili_master_key}
          FLUXER_S3_SECRET_KEY=${config.sops.placeholder.fluxer_s3_secret_key}
          FLUXER_SUDO_MODE_SECRET=${config.sops.placeholder.fluxer_sudo_mode_secret}
          FLUXER_CONNECTION_INITIATION_SECRET=${config.sops.placeholder.fluxer_connection_initiation_secret}
          FLUXER_GATEWAY_RPC_AUTH_TOKEN=${config.sops.placeholder.fluxer_gateway_rpc_auth_token}
          FLUXER_ERLANG_COOKIE=${config.sops.placeholder.fluxer_erlang_cookie}
          FLUXER_MEDIA_PROXY_SECRET_KEY=${config.sops.placeholder.fluxer_media_proxy_secret_key}
          FLUXER_MEDIA_PROXY_UPLOAD_RELAY_SECRET_BASE64=${config.sops.placeholder.fluxer_media_proxy_upload_relay_secret_base64}
          FLUXER_ADMIN_SECRET_KEY_BASE=${config.sops.placeholder.fluxer_admin_secret_key_base}
          FLUXER_ADMIN_OAUTH_CLIENT_SECRET=${config.sops.placeholder.fluxer_admin_oauth_client_secret}
          LIVEKIT_API_SECRET=${config.sops.placeholder.fluxer_livekit_api_secret}
          FLUXER_VAPID_PUBLIC_KEY=${config.sops.placeholder.fluxer_vapid_public_key}
          FLUXER_VAPID_PRIVATE_KEY=${config.sops.placeholder.fluxer_vapid_private_key}
        '';
        restartUnits = ["fluxer.service"];
      };

      systemd.services.fluxer = {
        description = "Fluxer chat stack (docker compose)";
        wantedBy = ["multi-user.target"];
        wants = ["network-online.target"];
        after = ["network-online.target" "podman.socket"];
        requires = ["podman.socket"];
        environment.DOCKER_HOST = "unix:///var/run/docker.sock";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StateDirectory = "fluxer";
          WorkingDirectory = projectDir;
          # The first start pulls every image in the stack.
          TimeoutStartSec = 0;
          ExecStartPre = pkgs.writeShellScript "fluxer-sync-stack" ''
            set -eu
            cd ${projectDir}
            ${lib.concatMapStringsSep "\n" (file: "install -m 0644 ${file} ${file.name}") composeFiles}
            install -m 0644 ${caddyfile} Caddyfile
            ln -sfn ${config.sops.templates."fluxer.env".path} .env
          '';
          ExecStart = "${compose} up -d --remove-orphans";
          ExecStop = "${compose} down";
        };
      };

      # LiveKit voice media never goes through a proxy; the router forwards
      # these ports to adam directly, like Soulseek's 50300.
      networking.firewall = {
        allowedTCPPorts = [7881];
        allowedUDPPorts = [7882];
      };

      services.homelab.caddy.virtualHosts."fluxer" = {
        inherit domain;
        # Public: chat clients connect from outside the LAN and tailnet.
        public = true;
        reverseProxy = "127.0.0.1:${toString edgePort}";
      };
    };
  };
}
