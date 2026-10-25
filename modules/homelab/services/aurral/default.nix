{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.aurral;
  lidarr = config.services.homelab.lidarr;
  mediaShare = config.services.homelab.mediaShare;
  domain = "discover.${config.services.homelab.domains.zekurio}";
  port = 3001;

  # Aurral serves its whole API without authentication until onboarding
  # completes, so complete it as soon as the server listens instead of
  # leaving the public vhost open for whoever reaches the setup page first.
  # Onboarding runs only once: rotating admin_password afterwards does not
  # change the Aurral account.
  onboard = pkgs.writeShellScript "aurral-onboard" ''
    set -euo pipefail
    api=http://127.0.0.1:${toString port}/api

    bootstrap=
    for _ in $(${pkgs.coreutils}/bin/seq 600); do
      bootstrap=$(${lib.getExe pkgs.curl} -fs "$api/health/bootstrap") && break
      ${pkgs.coreutils}/bin/sleep 0.1
    done
    if [ -z "$bootstrap" ]; then
      echo "Aurral did not answer on $api" >&2
      exit 1
    fi
    [ "$(${lib.getExe pkgs.jq} -r .onboardingRequired <<<"$bootstrap")" = true ] || exit 0

    ${lib.getExe pkgs.jq} -n \
      --arg user ${lib.escapeShellArg config.services.homelab.adminUsername} \
      --rawfile password "$CREDENTIALS_DIRECTORY/admin_password" \
      --arg url ${lib.escapeShellArg lidarr.baseUrl} \
      --rawfile apiKey "$CREDENTIALS_DIRECTORY/lidarr_api_key" \
      '{
        authUser: $user,
        authPassword: ($password | rtrimstr("\n")),
        lidarr: {url: $url, apiKey: ($apiKey | rtrimstr("\n")), searchOnAdd: true}
      }' \
      | ${lib.getExe pkgs.curl} -fsS -X POST -H 'Content-Type: application/json' \
        --data-binary @- "$api/onboarding/complete" >/dev/null
  '';
in {
  options.services.homelab.aurral = {
    enable = lib.mkEnableOption "Aurral music discovery and Lidarr requests with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lidarr.enable && mediaShare.enable;
        message = "Aurral requires the homelab Lidarr service and the shared music directory.";
      }
    ];

    services.aurral = {
      enable = true;
      inherit port;
      environment.AURRAL_PUBLIC_URL = "https://${domain}";
    };

    sops.secrets.lidarr_api_key = {};

    systemd.services.aurral = {
      after = ["lidarr.service"];
      wants = ["lidarr.service"];
      unitConfig.RequiresMountsFor = [mediaShare.musicDir];
      serviceConfig = {
        # Aurral reads the files at the paths Lidarr reports but never
        # writes into Lidarr's root folder.
        BindReadOnlyPaths = [mediaShare.musicDir];
        SupplementaryGroups = [mediaShare.group];
        # The confinement chroot hides /run/secrets; credentials reach it.
        LoadCredential = [
          "admin_password:${config.sops.secrets.admin_password.path}"
          "lidarr_api_key:${config.sops.secrets.lidarr_api_key.path}"
        ];
        ExecStartPost = ["${onboard}"];
      };
    };

    services.homelab.backup.stopUnits = ["aurral.service"];

    services.homelab.caddy.virtualHosts.aurral = {
      inherit domain;
      # Like Seerr, users request music from outside the LAN; Aurral's own
      # login guards the vhost.
      public = true;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
