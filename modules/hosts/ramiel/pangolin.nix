{
  flake.modules.nixos.ramiel = {
    config,
    lib,
    pkgs,
    ...
  }: let
    stateDir = "/var/lib/pangolin";
    configDir = "${stateDir}/config";

    dashboardDomain = "pangolin.zekurio.me";
    # Both zones are offered to Pangolin so resources can be created on either
    # without touching this file again.
    baseDomain = "zekurio.me";
    mediaDomain = "schnitzelflix.xyz";
    acmeEmail = "admin@zekurio.me";

    # Pinned against upstream's installer templates (fosrl/pangolin install/).
    versions = {
      # Enterprise Edition image. Behaves exactly like Community until a key is
      # activated under Server Admin -> License, so the switch is safe on its
      # own; the licence itself lives in Pangolin's database, not here.
      pangolin = "ee-1.21.0";
      gerbil = "1.4.3";
      traefik = "v3.7.9";
      crowdsec = "v1.7.8";
      badger = "v1.5.0";
      crowdsecBouncerPlugin = "v1.4.4";
    };

    pangolinConfig = pkgs.writeText "pangolin-config.yml" ''
      gerbil:
        start_port: 51820
        base_endpoint: "${dashboardDomain}"
      app:
        dashboard_url: "https://${dashboardDomain}"
        log_level: "info"
        telemetry:
          anonymous_usage: false
      domains:
        domain1:
          base_domain: "${baseDomain}"
          prefer_wildcard_cert: true
          cert_resolver: "letsencrypt"
        domain2:
          base_domain: "${mediaDomain}"
          prefer_wildcard_cert: true
          cert_resolver: "letsencrypt"
      server:
        cors:
          origins: ["https://${dashboardDomain}"]
          methods: ["GET", "POST", "PUT", "DELETE", "PATCH"]
          allowed_headers: ["X-CSRF-Token", "Content-Type"]
          credentials: false
      flags:
        require_email_verification: false
        disable_signup_without_invite: true
        disable_user_create_org: false
        allow_raw_resources: true
    '';

    # Enterprise-only file, ignored by the Community build. "org" scopes
    # identity providers to a single organisation instead of sharing the
    # server's global IdPs with every org, so each org can bring its own
    # Pocket ID instance. Global IdPs stop being offered once this is set.
    pangolinPrivateConfig = pkgs.writeText "pangolin-private-config.yml" ''
      app:
        identity_provider_mode: "org"
    '';

    traefikStaticConfig = pkgs.writeText "traefik_config.yml" ''
      api:
        insecure: true
        dashboard: true
      providers:
        http:
          endpoint: "http://pangolin:3001/api/v1/traefik-config"
          pollInterval: "5s"
        file:
          filename: "/etc/traefik/dynamic_config.yml"
      experimental:
        plugins:
          badger:
            moduleName: "github.com/fosrl/badger"
            version: "${versions.badger}"
          crowdsec:
            moduleName: "github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin"
            version: "${versions.crowdsecBouncerPlugin}"
      log:
        level: "INFO"
        format: "json"
        maxSize: 100
        maxBackups: 3
        maxAge: 3
        compress: true
      accessLog:
        filePath: "/var/log/traefik/access.log"
        format: "json"
        bufferingSize: 100
        filters:
          statusCodes: ["200-299", "400-499", "500-599"]
          retryAttempts: true
          minDuration: "100ms"
        fields:
          defaultMode: keep
          headers:
            defaultMode: keep
            names:
              Authorization: redact
              Cookie: redact
      certificatesResolvers:
        letsencrypt:
          acme:
            # DNS-01 rather than HTTP-01: wildcard certificates are only issued
            # over DNS, and one per zone replaces a certificate per hostname.
            # The single resolver is deliberate - a second one would race the
            # first for the same names against Let's Encrypt's rate limits.
            dnsChallenge:
              provider: "cloudflare"
              resolvers:
                - "1.1.1.1:53"
                - "1.0.0.1:53"
            email: "${acmeEmail}"
            storage: "/letsencrypt/acme.json"
            caServer: "https://acme-v02.api.letsencrypt.org/directory"
      entryPoints:
        web:
          address: ":80"
        websecure:
          address: ":443"
          transport:
            respondingTimeouts:
              readTimeout: "30m"
          http3:
            advertisedPort: 443
          http:
            tls:
              certResolver: "letsencrypt"
            encodedCharacters:
              allowEncodedSlash: true
              allowEncodedQuestionMark: true
            # Entrypoint-level so that resource routers, which Pangolin feeds
            # in over the HTTP provider, inherit them too. Only the dashboard
            # routers are defined in the file provider.
            middlewares:
              - crowdsec@file
              - security-headers@file
      serversTransport:
        insecureSkipVerify: true
      ping:
        entryPoint: "web"
    '';

    crowdsecAcquisTraefik = pkgs.writeText "crowdsec-acquis-traefik.yaml" ''
      filenames:
        - /var/log/traefik/*.log
      labels:
        type: traefik
    '';

    crowdsecAcquisAppsec = pkgs.writeText "crowdsec-acquis-appsec.yaml" ''
      listen_addr: 0.0.0.0:7422
      appsec_config: crowdsecurity/appsec-default
      name: myAppSecComponent
      source: appsec
      labels:
        type: appsec
    '';

    crowdsecProfiles = pkgs.writeText "crowdsec-profiles.yaml" ''
      name: default_ip_remediation
      filters:
        - Alert.Remediation == true && Alert.GetScope() == "Ip"
      decisions:
        - type: ban
          duration: 4h
      duration_expr: Sprintf('%dh', GetDecisionsCount(Alert.GetValue())+1)
      on_success: break
      ---
      name: default_range_remediation
      filters:
        - Alert.Remediation == true && Alert.GetScope() == "Range"
      decisions:
        - type: ban
          duration: 4h
      duration_expr: Sprintf('%dh', GetDecisionsCount(Alert.GetValue())+1)
      on_success: break
    '';
  in {
    virtualisation.docker.enable = true;
    virtualisation.oci-containers.backend = "docker";

    # cscli lives inside the container; this makes it usable as a normal
    # command, e.g. `cscli decisions list` or `cscli metrics`.
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "cscli" ''
        exec ${pkgs.docker}/bin/docker exec crowdsec cscli "$@"
      '')
    ];

    sops.secrets.pangolin_env = {
      mode = "0400";
    };
    sops.secrets.crowdsec_bouncer_key = {
      mode = "0400";
    };
    # Cloudflare token traefik uses to solve DNS-01 challenges. Scoped to
    # Zone:Read plus DNS:Edit on the two zones, nothing else.
    sops.secrets.traefik_env = {
      mode = "0400";
    };

    # The only config file containing a secret (the CrowdSec bouncer key).
    # Every container runs as root, so it never needs to be world-readable.
    sops.templates."traefik-dynamic-config.yml" = {
      mode = "0400";
      content = ''
        http:
          middlewares:
            badger:
              plugin:
                badger:
                  disableForwardAuth: true
            redirect-to-https:
              redirectScheme:
                scheme: https
            security-headers:
              headers:
                stsSeconds: 63072000
                stsIncludeSubdomains: true
                stsPreload: true
                contentTypeNosniff: true
                customFrameOptionsValue: "SAMEORIGIN"
                referrerPolicy: "strict-origin-when-cross-origin"
                customResponseHeaders:
                  Server: ""
                  X-Powered-By: ""
                  # Matches what Caddy sets on every vhost on adam, so moving a
                  # service to the edge does not make it search-indexable.
                  X-Robots-Tag: "noindex, nofollow"
            crowdsec:
              plugin:
                crowdsec:
                  enabled: true
                  crowdsecMode: live
                  crowdsecLapiHost: "crowdsec:8080"
                  crowdsecLapiScheme: "http"
                  crowdsecLapiKey: "${config.sops.placeholder.crowdsec_bouncer_key}"
                  crowdsecAppsecEnabled: true
                  crowdsecAppsecHost: "crowdsec:7422"
                  crowdsecAppsecFailureBlock: true
                  crowdsecAppsecUnreachableBlock: true
                  crowdsecAppsecBodyLimit: 10485760
                  updateIntervalSeconds: 15
                  defaultDecisionSeconds: 15
                  forwardedHeadersTrustedIPs:
                    - "0.0.0.0/0"
                  clientTrustedIPs:
                    - "10.0.0.0/8"
                    - "192.168.0.0/16"
                    - "172.16.0.0/12"
                    - "100.89.137.0/20"
          routers:
            main-app-router-redirect:
              rule: "Host(`${dashboardDomain}`)"
              service: next-service
              entryPoints:
                - web
              middlewares:
                - redirect-to-https
                - badger
            next-router:
              rule: "Host(`${dashboardDomain}`) && !PathPrefix(`/api/v1`)"
              service: next-service
              entryPoints:
                - websecure
              middlewares:
                - badger
                - security-headers
              tls:
                certResolver: letsencrypt
                # prefer_wildcard_cert only covers routers Pangolin generates,
                # so the dashboard asks for the wildcard explicitly.
                domains:
                  - main: "${baseDomain}"
                    sans:
                      - "*.${baseDomain}"
            api-router:
              rule: "Host(`${dashboardDomain}`) && PathPrefix(`/api/v1`)"
              service: api-service
              entryPoints:
                - websecure
              middlewares:
                - badger
                - security-headers
              tls:
                certResolver: letsencrypt
            ws-router:
              rule: "Host(`${dashboardDomain}`)"
              service: api-service
              entryPoints:
                - websecure
              middlewares:
                - badger
                - security-headers
              tls:
                certResolver: letsencrypt
          services:
            next-service:
              loadBalancer:
                servers:
                  - url: "http://pangolin:3002"
            api-service:
              loadBalancer:
                servers:
                  - url: "http://pangolin:3000"
        tcp:
          serversTransports:
            pp-transport-v1:
              proxyProtocol:
                version: 1
            pp-transport-v2:
              proxyProtocol:
                version: 2
      '';
    };

    systemd.services =
      {
        # Stateful layout under /var/lib/pangolin/config, mirroring upstream's
        # install-dir layout, plus the CrowdSec config files crowdsec expects
        # in a writable /etc/crowdsec.
        pangolin-config-seed = {
          description = "Seed Pangolin state directories and CrowdSec config";
          wantedBy = ["multi-user.target"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            # 0700 on the tree: gerbil writes its WireGuard private key and
            # pangolin its SQLite database (sessions, site credentials) here,
            # both with world-readable modes of their own. All containers run
            # as root, so nothing needs traversal from other accounts.
            install -d -m 0700 -o root -g root ${stateDir} ${configDir}
            install -d -m 0700 -o root -g root \
              ${configDir}/db ${configDir}/letsencrypt \
              ${configDir}/traefik ${configDir}/traefik/logs \
              ${configDir}/crowdsec ${configDir}/crowdsec/acquis.d ${configDir}/crowdsec/db
            cp -f ${crowdsecAcquisTraefik} ${configDir}/crowdsec/acquis.d/traefik.yaml
            cp -f ${crowdsecAcquisAppsec} ${configDir}/crowdsec/acquis.d/appsec.yaml
            cp -f ${crowdsecProfiles} ${configDir}/crowdsec/profiles.yaml
            # Defence in depth for the two files that carry key material.
            chmod 0600 ${configDir}/key ${configDir}/db/db.sqlite 2>/dev/null || true
          '';
        };

        docker-network-pangolin = {
          description = "Create the pangolin_frontend docker network";
          after = ["docker.service"];
          requires = ["docker.service"];
          wantedBy = ["multi-user.target"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            ${pkgs.docker}/bin/docker network inspect pangolin_frontend >/dev/null 2>&1 \
              || ${pkgs.docker}/bin/docker network create pangolin_frontend
          '';
        };

        # Register the traefik bouncer key with the CrowdSec LAPI, idempotently.
        crowdsec-bouncer-setup = {
          description = "Register the Traefik bouncer with CrowdSec";
          after = ["docker-crowdsec.service"];
          requires = ["docker-crowdsec.service"];
          wantedBy = ["multi-user.target"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            TimeoutStartSec = "180s";
          };
          # Also acts as traefik's readiness gate: the bouncer plugin resolves
          # and calls the LAPI at startup, so traefik is ordered after this.
          script = ''
            docker="${pkgs.docker}/bin/docker"
            for _ in $(seq 1 60); do
              $docker exec crowdsec cscli lapi status >/dev/null 2>&1 && break
              sleep 2
            done
            if ! $docker exec crowdsec cscli bouncers list -o json | ${pkgs.jq}/bin/jq -e '.[] | select(.name == "traefik-bouncer")' >/dev/null 2>&1; then
              $docker exec crowdsec cscli bouncers add traefik-bouncer --key "$(cat ${config.sops.secrets.crowdsec_bouncer_key.path})"
            fi
          '';
        };
      }
      # Ordering: every container needs the seed (dirs/configs) and the network.
      // lib.genAttrs ["docker-pangolin" "docker-gerbil" "docker-traefik" "docker-crowdsec"] (name: {
        after =
          ["pangolin-config-seed.service" "docker-network-pangolin.service"]
          # Soft dependency: a broken CrowdSec delays traefik but never keeps
          # the edge down (the wait above is bounded).
          ++ lib.optional (name == "docker-traefik") "crowdsec-bouncer-setup.service";
        requires = ["pangolin-config-seed.service" "docker-network-pangolin.service"];
        wants = lib.optional (name == "docker-traefik") "crowdsec-bouncer-setup.service";
      });

    virtualisation.oci-containers.containers = {
      pangolin = {
        image = "docker.io/fosrl/pangolin:${versions.pangolin}";
        volumes = [
          "${pangolinConfig}:/app/config/config.yml:ro"
          "${pangolinPrivateConfig}:/app/config/privateConfig.yml:ro"
          "${configDir}/db:/app/config/db"
          # Pangolin reads Traefik's ACME store to learn which certificates
          # exist; without it every certificate shows as pending in the
          # dashboard even while Traefik serves them fine.
          "${configDir}/letsencrypt:/app/config/letsencrypt:ro"
        ];
        environmentFiles = [config.sops.secrets.pangolin_env.path];
        extraOptions = [
          "--network=pangolin_frontend"
          "--memory=2g"
          "--memory-reservation=512m"
        ];
      };

      gerbil = {
        image = "docker.io/fosrl/gerbil:${versions.gerbil}";
        cmd = [
          "--reachableAt=http://gerbil:3004"
          "--generateAndSaveKeyTo=/var/config/key"
          "--remoteConfig=http://pangolin:3001/api/v1/"
        ];
        volumes = ["${configDir}:/var/config"];
        ports = [
          "80:80"
          "443:443"
          "443:443/udp"
          "51820:51820/udp"
          "21820:21820/udp"
        ];
        extraOptions = [
          "--network=pangolin_frontend"
          "--cap-add=NET_ADMIN"
          "--cap-add=SYS_MODULE"
        ];
        dependsOn = ["pangolin"];
      };

      traefik = {
        image = "docker.io/traefik:${versions.traefik}";
        cmd = ["--configFile=/etc/traefik/traefik_config.yml"];
        environmentFiles = [config.sops.secrets.traefik_env.path];
        volumes = [
          "${traefikStaticConfig}:/etc/traefik/traefik_config.yml:ro"
          "${config.sops.templates."traefik-dynamic-config.yml".path}:/etc/traefik/dynamic_config.yml:ro"
          "${configDir}/letsencrypt:/letsencrypt"
          "${configDir}/traefik/logs:/var/log/traefik"
        ];
        # Shares gerbil's network namespace; gerbil publishes the ports.
        extraOptions = ["--network=container:gerbil"];
        # CrowdSec first: the bouncer plugin resolves "crowdsec" at startup.
        dependsOn = ["pangolin" "gerbil" "crowdsec"];
      };

      crowdsec = {
        image = "docker.io/crowdsecurity/crowdsec:${versions.crowdsec}";
        environment = {
          GID = "1000";
          COLLECTIONS = "crowdsecurity/traefik crowdsecurity/appsec-virtual-patching crowdsecurity/appsec-generic-rules";
          PARSERS = "crowdsecurity/whitelists";
        };
        volumes = [
          "${configDir}/crowdsec:/etc/crowdsec"
          "${configDir}/crowdsec/db:/var/lib/crowdsec/data"
          "${configDir}/traefik/logs:/var/log/traefik:ro"
        ];
        extraOptions = ["--network=pangolin_frontend"];
      };
    };

    # Traefik rotates its own main log but not access.log.
    services.logrotate.settings.pangolin-traefik = {
      files = "${configDir}/traefik/logs/access.log";
      frequency = "daily";
      rotate = 7;
      compress = true;
      delaycompress = true;
      copytruncate = true;
      missingok = true;
      notifempty = true;
      su = "root root";
    };
  };
}
