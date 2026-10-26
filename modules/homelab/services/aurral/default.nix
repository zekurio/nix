{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.aurral;
  mediaShare = config.services.homelab.mediaShare;
  sabnzbd = config.services.homelab.sabnzbd;
  domain = "music.${config.services.homelab.domains.zekurio}";
  port = 3001;
  # Aurral files downloads into the library that slskd shares, and adopts
  # the music already there in place.
  libraryDir = mediaShare.musicDir;
  slskdDownloads = config.services.slskd.settings.directories.downloads;
  # Storage health test-writes to SABnzbd's root completed folder, not the
  # category's, so bind the root; jobs land in categories.aurral.dir below it.
  usenetDownloads = lib.optional sabnzbd.enable config.services.sabnzbd.settings.misc.complete_dir;

  # The settings Nix owns. The configure script adds each client's API key
  # from the credential named <client>_api_key.
  settings = pkgs.writeText "aurral-settings.json" (builtins.toJSON {
    downloadFolderPath = libraryDir;
    # Lidarr's root was this folder. Aurral's folder migration, which 3.0
    # requires, stops at any saved Lidarr root inside it, even with Lidarr off.
    # The settings store skips null, so clear it with an empty path.
    rootFolderPath = "";
    integrations =
      {
        # Lidarr is gone. Drop its connection and its saved root, which the
        # migration counts too.
        lidarr = {
          enabled = false;
          url = "";
          apiKey = "";
          rootFolderPath = "";
          rootFolderPaths = [];
        };
        slskd = {
          enabled = true;
          url = "http://127.0.0.1:${toString config.services.slskd.settings.web.port}${config.services.slskd.settings.web.url_base}";
        };
      }
      // lib.optionalAttrs sabnzbd.enable {
        sabnzbd = {
          enabled = true;
          url = sabnzbd.baseUrl;
          category = "aurral";
        };
      };
  });
  apiKeyClients = ["slskd"] ++ lib.optional sabnzbd.enable "sabnzbd";

  curl = lib.getExe pkgs.curl;
  jq = lib.getExe pkgs.jq;

  # Aurral reads its API key only from its database, so write the managed key
  # there before the server starts. Rotating the key in the UI lasts until
  # the next start.
  seedApiKey = let
    package = config.services.aurral.package;
  in
    pkgs.writeShellScript "aurral-seed-api-key" ''
      export LD_LIBRARY_PATH=${lib.makeLibraryPath [pkgs.sqlite]}
      exec ${lib.getExe package.nodejs} --input-type=module -e '
        import { readFileSync } from "node:fs";
        import { dbOps } from "${package}/lib/node_modules/aurral/backend/db/helpers/index.js";
        const apiKey = readFileSync(process.env.CREDENTIALS_DIRECTORY + "/aurral_api_key", "utf8").trim();
        const settings = dbOps.getSettings();
        dbOps.updateSettings({
          ...settings,
          integrations: {
            ...settings.integrations,
            general: { ...settings.integrations?.general, apiKey },
          },
        });
      '
    '';

  # Aurral serves its whole API without authentication until onboarding
  # completes, so complete it as soon as the server listens instead of
  # leaving the public vhost open for whoever reaches the setup page first.
  # Without a password, onboarding creates no local account; the first
  # Pocket ID sign-in of adminUsername becomes the admin. Afterwards,
  # reapply the settings Nix owns; the API merges each integration, so
  # UI-only fields survive.
  configure = pkgs.writeShellScript "aurral-configure" ''
    set -euo pipefail
    api=http://127.0.0.1:${toString port}/api

    bootstrap=
    for _ in $(${pkgs.coreutils}/bin/seq 600); do
      bootstrap=$(${curl} -fs "$api/health/bootstrap") && break
      ${pkgs.coreutils}/bin/sleep 0.1
    done
    if [ -z "$bootstrap" ]; then
      echo "Aurral did not answer on $api" >&2
      exit 1
    fi

    if [ "$(${jq} -r .onboardingRequired <<<"$bootstrap")" = true ]; then
      ${curl} -fsS -X POST -H 'Content-Type: application/json' \
        --data ${lib.escapeShellArg (builtins.toJSON {downloadFolderPath = libraryDir;})} \
        "$api/onboarding/complete" >/dev/null
    fi

    body=$(<${settings})
    for client in ${lib.escapeShellArgs apiKeyClients}; do
      body=$(printf '%s' "$body" | ${jq} --arg client "$client" \
        --rawfile key "$CREDENTIALS_DIRECTORY/''${client}_api_key" \
        '.integrations[$client].apiKey = ($key | rtrimstr("\n"))')
    done
    # Headers and bodies go through pipes, keeping the API keys out of the
    # process list.
    printf '%s' "$body" \
      | ${curl} -fsS -X POST \
        -H @<(printf 'X-Api-Key: %s\n' "$(<"$CREDENTIALS_DIRECTORY/aurral_api_key")") \
        -H 'Content-Type: application/json' --data-binary @- "$api/settings" >/dev/null
  '';
in {
  options.services.homelab.aurral = {
    enable = lib.mkEnableOption "Aurral music discovery, downloads, and library with Pocket ID sign-in and Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = mediaShare.enable && config.services.homelab.slskd.enable;
        message = "Aurral requires the shared music directory and the homelab slskd service.";
      }
      {
        assertion = config.services.homelab.pocket-id.enable;
        message = "Aurral signs in through the homelab Pocket ID service.";
      }
    ];

    services.aurral = {
      enable = true;
      inherit port;
      # Bound read-write: Aurral moves completed downloads out of these and
      # deletes what it did not take.
      directories = [libraryDir slskdDownloads] ++ usenetDownloads;
      environment = {
        AURRAL_PUBLIC_URL = "https://${domain}";
        FILE_BROWSE_ROOTS = libraryDir;
        OIDC_ENABLED = "true";
        OIDC_ISSUER = config.services.pocket-id.settings.APP_URL;
        OIDC_REDIRECT_URI = "https://${domain}/sso/callback";
        # Pocket ID sets the role at every sign-in, so admin rights follow
        # this list rather than the role shown in Aurral.
        OIDC_ADMIN_USERS = config.services.homelab.adminUsername;
      };
      # Supplies OIDC_CLIENT_ID and OIDC_CLIENT_SECRET from the Pocket ID client.
      environmentFile = config.sops.secrets.aurral_env.path;
    };

    sops.secrets = {
      aurral_api_key.restartUnits = ["aurral.service"];
      aurral_env.restartUnits = ["aurral.service"];
      slskd_api_key = {};
      sabnzbd_api_key = lib.mkIf sabnzbd.enable {};
    };

    systemd.services.aurral = {
      after = ["slskd.service"] ++ lib.optional sabnzbd.enable "sabnzbd.service";
      wants = ["slskd.service"] ++ lib.optional sabnzbd.enable "sabnzbd.service";
      unitConfig.RequiresMountsFor = [libraryDir slskdDownloads] ++ usenetDownloads;
      serviceConfig = {
        SupplementaryGroups = [mediaShare.group];
        UMask = lib.mkForce mediaShare.umask;
        # The confinement chroot hides /run/secrets; credentials reach it.
        LoadCredential =
          [
            "aurral_api_key:${config.sops.secrets.aurral_api_key.path}"
            "slskd_api_key:${config.sops.secrets.slskd_api_key.path}"
          ]
          ++ lib.optional sabnzbd.enable "sabnzbd_api_key:${config.sops.secrets.sabnzbd_api_key.path}";
        ExecStartPre = ["${seedApiKey}"];
        ExecStartPost = ["${configure}"];
      };
    };

    services.homelab.backup.stopUnits = ["aurral.service"];

    services.homelab.caddy.virtualHosts.aurral = {
      inherit domain;
      # Pocket ID sign-in guards the vhost; Subsonic apps reach /rest with a
      # local Aurral password.
      public = true;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
