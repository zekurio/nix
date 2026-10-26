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

  # Keep the admin account on the shared admin password, as admin-password.nix
  # does for the Servarr apps, so the configure script can always sign in.
  # Aurral's reset script reads the password from argv and prints it; set
  # argv inside Node and discard stdout to keep it out of ps and the journal.
  resetAdminPassword = let
    package = config.services.aurral.package;
  in
    pkgs.writeShellScript "aurral-reset-admin-password" ''
      export LD_LIBRARY_PATH=${lib.makeLibraryPath [pkgs.sqlite]}
      export AURRAL_ADMIN_USER=${lib.escapeShellArg config.services.homelab.adminUsername}
      exec ${lib.getExe package.nodejs} --input-type=module -e '
        import { readFileSync } from "node:fs";
        const password = readFileSync(process.env.CREDENTIALS_DIRECTORY + "/admin_password", "utf8")
          .replace(/\r?\n$/, "");
        process.argv = [process.argv[0], "resetAdminPassword",
          "--username", process.env.AURRAL_ADMIN_USER, "--password", password];
        await import("${package}/lib/node_modules/aurral/backend/scripts/resetAdminPassword.js");
      ' >/dev/null
    '';

  # Aurral serves its whole API without authentication until onboarding
  # completes, so complete it as soon as the server listens instead of
  # leaving the public vhost open for whoever reaches the setup page first.
  # Afterwards, sign in as the admin and reapply the settings Nix owns; the
  # API merges each integration, so UI-only fields survive.
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
      ${jq} -n \
        --arg user ${lib.escapeShellArg config.services.homelab.adminUsername} \
        --rawfile password "$CREDENTIALS_DIRECTORY/admin_password" \
        --arg folder ${lib.escapeShellArg libraryDir} \
        '{
          authUser: $user,
          authPassword: ($password | rtrimstr("\n")),
          downloadFolderPath: $folder
        }' \
        | ${curl} -fsS -X POST -H 'Content-Type: application/json' \
          --data-binary @- "$api/onboarding/complete" >/dev/null
    fi

    login=$(${jq} -n \
      --arg user ${lib.escapeShellArg config.services.homelab.adminUsername} \
      --rawfile password "$CREDENTIALS_DIRECTORY/admin_password" \
      '{username: $user, password: ($password | rtrimstr("\n"))}' \
      | ${curl} -sS -X POST -H 'Content-Type: application/json' \
        --data-binary @- -w '\n%{http_code}' "$api/auth/login")
    case ''${login##*$'\n'} in
      200) ;;
      401)
        # ExecStartPre resets the account to admin_password, so this means
        # the account was renamed. The last synced settings stay.
        echo "Aurral rejected admin_password; settings were not synced." >&2
        exit 0
        ;;
      *)
        echo "Aurral sign-in failed: ''${login%$'\n'*}" >&2
        exit 1
        ;;
    esac
    # Headers and bodies go through files and pipes, keeping the session
    # token and API keys out of the process list.
    auth="Authorization: Bearer $(${jq} -r .token <<<"''${login%$'\n'*}")"

    body=$(<${settings})
    for client in ${lib.escapeShellArgs apiKeyClients}; do
      body=$(printf '%s' "$body" | ${jq} --arg client "$client" \
        --rawfile key "$CREDENTIALS_DIRECTORY/''${client}_api_key" \
        '.integrations[$client].apiKey = ($key | rtrimstr("\n"))')
    done
    printf '%s' "$body" \
      | ${curl} -fsS -X POST -H @<(echo "$auth") -H 'Content-Type: application/json' \
        --data-binary @- "$api/settings" >/dev/null
    # The admin's own Lidarr defaults count as a Lidarr root too.
    ${curl} -fsS -X PATCH -H @<(echo "$auth") -H 'Content-Type: application/json' \
      --data '{"rootFolderPath": null, "qualityProfileId": null}' \
      "$api/users/me/lidarr-preferences" >/dev/null
    ${curl} -fsS -X POST -H @<(echo "$auth") "$api/auth/logout" >/dev/null
  '';
in {
  options.services.homelab.aurral = {
    enable = lib.mkEnableOption "Aurral music discovery, downloads, and library with Caddy integration";
    oidc.enable = lib.mkEnableOption "Pocket ID sign-in, which needs the client's credentials in the aurral_env secret";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = mediaShare.enable && config.services.homelab.slskd.enable;
        message = "Aurral requires the shared music directory and the homelab slskd service.";
      }
      {
        assertion = cfg.oidc.enable -> config.services.homelab.pocket-id.enable;
        message = "Aurral's OIDC sign-in requires the homelab Pocket ID service.";
      }
    ];

    services.aurral = {
      enable = true;
      inherit port;
      # Bound read-write: Aurral moves completed downloads out of these and
      # deletes what it did not take.
      directories = [libraryDir slskdDownloads] ++ usenetDownloads;
      environment =
        {
          AURRAL_PUBLIC_URL = "https://${domain}";
          FILE_BROWSE_ROOTS = libraryDir;
        }
        // lib.optionalAttrs cfg.oidc.enable {
          OIDC_ENABLED = "true";
          OIDC_ISSUER = config.services.pocket-id.settings.APP_URL;
          OIDC_REDIRECT_URI = "https://${domain}/sso/callback";
          # Pocket ID sets the role at every sign-in, so admin rights follow
          # this list rather than the role shown in Aurral.
          OIDC_ADMIN_USERS = config.services.homelab.adminUsername;
        };
      # Supplies OIDC_CLIENT_ID and OIDC_CLIENT_SECRET from the Pocket ID client.
      environmentFile = lib.mkIf cfg.oidc.enable config.sops.secrets.aurral_env.path;
    };

    sops.secrets = {
      admin_password.restartUnits = ["aurral.service"];
      aurral_env = lib.mkIf cfg.oidc.enable {restartUnits = ["aurral.service"];};
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
            "admin_password:${config.sops.secrets.admin_password.path}"
            "slskd_api_key:${config.sops.secrets.slskd_api_key.path}"
          ]
          ++ lib.optional sabnzbd.enable "sabnzbd_api_key:${config.sops.secrets.sabnzbd_api_key.path}";
        ExecStartPre = ["${resetAdminPassword}"];
        ExecStartPost = ["${configure}"];
      };
    };

    services.homelab.backup.stopUnits = ["aurral.service"];

    services.homelab.caddy.virtualHosts.aurral = {
      inherit domain;
      # Aurral's login, or Pocket ID with oidc.enable, guards the vhost;
      # Subsonic apps reach /rest with a local Aurral password.
      public = true;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
