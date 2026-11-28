{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.aurral;
  homelab = config.services.homelab;
  mediaShare = homelab.mediaShare;
  domain = "music.${homelab.domains.zekurio}";
  publicUrl = "https://${domain}";
  port = 3001;
  # slskd and the aurral SABnzbd category both finish downloads here.
  # Aurral reads them at the paths the clients report, then copies them
  # into the Library and deletes the client's copy.
  completeDir = "${mediaShare.downloadsRoot}/complete";
  sabnzbdCategory = "aurral";

  secrets = [
    "admin_password"
    "aurral_api_key"
    "prowlarr_api_key"
    "sabnzbd_api_key"
    "slskd_api_key"
  ];

  # Aurral keeps the Library folder and its download clients in its
  # database, behind its admin API, so they are set through that API.
  provision = pkgs.writeShellApplication {
    name = "aurral-provision";
    runtimeInputs = [pkgs.curl pkgs.jq];
    text = ''
      api=http://127.0.0.1:${toString port}/api
      creds=$CREDENTIALS_DIRECTORY

      # The first start migrates and indexes before it listens.
      curl --silent --show-error --fail --retry 150 --retry-delay 2 --retry-all-errors \
        --output /dev/null "$api/health/live"

      # Until onboarding completes, Aurral serves its whole API without
      # authentication, so finish it before anything else can. Secrets go
      # through files: arguments show up in the process list.
      if [ "$(curl -sSf "$api/health/bootstrap" | jq .onboardingRequired)" = true ]; then
        jq -n \
          --arg user ${lib.escapeShellArg homelab.adminUsername} \
          --rawfile password "$creds/admin_password" \
          --arg library ${lib.escapeShellArg mediaShare.musicDir} \
          '{
            authUser: $user,
            authPassword: ($password | rtrimstr("\n")),
            downloadFolderPath: $library,
            security: {localNetworkBypass: {enabled: false}}
          }' |
          curl -sSf -H 'Content-Type: application/json' --data-binary @- \
            --output /dev/null "$api/onboarding/complete"
      fi

      # Each integration merges into what is stored, so priorities and
      # indexer choices made in the UI survive a rerun.
      jq -n \
        --rawfile slskd "$creds/slskd_api_key" \
        --rawfile prowlarr "$creds/prowlarr_api_key" \
        --rawfile sabnzbd "$creds/sabnzbd_api_key" \
        '{integrations: {
          slskd: {
            enabled: true,
            url: "http://127.0.0.1:5030/slskd",
            apiKey: ($slskd | rtrimstr("\n"))
          },
          prowlarr: {
            enabled: true,
            url: "http://127.0.0.1:9696/prowlarr",
            apiKey: ($prowlarr | rtrimstr("\n"))
          },
          sabnzbd: {
            enabled: true,
            url: ${builtins.toJSON homelab.sabnzbd.baseUrl},
            apiKey: ($sabnzbd | rtrimstr("\n")),
            category: "${sabnzbdCategory}"
          }
        }}' |
        curl -sSf -H 'Content-Type: application/json' \
          -H @<(printf 'X-Api-Key: %s\n' "$(tr -d '\n' < "$creds/aurral_api_key")") \
          --data-binary @- --output /dev/null "$api/settings"
    '';
  };
in {
  options.services.homelab.aurral.enable = lib.mkEnableOption "Aurral music discovery, library and Subsonic server with Caddy integration";

  config = lib.mkIf cfg.enable {
    assertions =
      map (name: {
        assertion = homelab.${name}.enable;
        message = "services.homelab.aurral requires services.homelab.${name}.";
      }) [
        "mediaShare"
        "pocket-id"
        "prowlarr"
        "sabnzbd"
        "slskd"
      ];

    services.aurral = {
      enable = true;
      inherit port;
      # Bound into the confined unit. LIBRARY_FOLDER stays unset: newer
      # module versions chown that folder to aurral:aurral 0770, and the
      # music tree belongs to the share group. Provisioning sets it instead.
      directories = [mediaShare.musicDir completeDir];
      environment = {
        AURRAL_PUBLIC_URL = publicUrl;
        # Pocket ID's client for Aurral needs this as its callback URL.
        OIDC_ENABLED = "true";
        OIDC_ISSUER = "https://auth.${homelab.domains.zekurio}";
        # Not a secret: the browser sees it in every sign-in redirect.
        OIDC_CLIENT_ID = "6d08ae8c-045c-45a7-b4a3-0b7358777702";
        OIDC_REDIRECT_URI = "${publicUrl}/sso/callback";
        OIDC_ADMIN_USERS = homelab.adminUsername;
      };
      environmentFile = config.sops.templates."aurral.env".path;
    };

    systemd.services.aurral = {
      unitConfig.RequiresMountsFor = [mediaShare.musicDir completeDir];
      serviceConfig = {
        SupplementaryGroups = [mediaShare.group];
        # The module's 0007 would hide new tracks from the SMB and NFS shares.
        UMask = lib.mkForce mediaShare.umask;
      };
    };

    systemd.services.aurral-provision = {
      description = "Provision Aurral's admin account and download clients";
      wantedBy = ["aurral.service"];
      after = ["aurral.service"];
      # Rerun whenever Aurral restarts.
      partOf = ["aurral.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe provision;
        DynamicUser = true;
        LoadCredential = map (name: "${name}:${config.sops.secrets.${name}.path}") secrets;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
      };
    };

    # Usenet downloads land in their own folder, as Radarr's and Sonarr's do.
    services.sabnzbd.settings.categories.${sabnzbdCategory} = {
      name = sabnzbdCategory;
      dir = "${completeDir}/${sabnzbdCategory}";
      pp = 3;
      priority = 0;
      newzbin = "";
      script = "None";
    };

    sops = {
      secrets =
        lib.genAttrs secrets (_: {
          restartUnits = ["aurral-provision.service"];
        })
        // {
          aurral_oidc_client_secret = {};
        };
      templates."aurral.env" = {
        content = ''
          AURRAL_API_KEY=${config.sops.placeholder.aurral_api_key}
          OIDC_CLIENT_SECRET=${config.sops.placeholder.aurral_oidc_client_secret}
        '';
        # EnvironmentFile is read once at start.
        restartUnits = ["aurral.service"];
      };
    };

    # Public, as Navidrome was: Subsonic apps, music.aurral.org and share
    # links reach it from outside the tailnet. Aurral's own login guards it.
    services.homelab.caddy.virtualHosts.aurral = {
      inherit domain;
      public = true;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
