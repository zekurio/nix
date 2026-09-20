{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.forgejo;
    dataDir = "/tank/forgejo";
    domain = "git.${config.services.homelab.domains.zekurio}";
    port = 3000;
    forgejo = lib.getExe config.services.forgejo.package;
    pocketIdDiscoveryUrl = "https://auth.${config.services.homelab.domains.zekurio}/.well-known/openid-configuration";
  in {
    options.services.homelab.forgejo.enable =
      lib.mkEnableOption "Forgejo software forge with Caddy and Pocket ID integration";

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.homelab.pocket-id.enable;
          message = "services.homelab.forgejo requires services.homelab.pocket-id.";
        }
      ];

      services.forgejo = {
        enable = true;
        repositoryRoot = "${dataDir}/repos";
        lfs = {
          enable = true;
          contentDir = "${dataDir}/lfs";
        };
        dump = {
          enable = true;
          type = "tar.zst";
        };
        settings = {
          server = {
            DOMAIN = domain;
            ROOT_URL = "https://${domain}/";
            HTTP_ADDR = "127.0.0.1";
            HTTP_PORT = port;
            SSH_DOMAIN = domain;
          };
          service.ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
          oauth2_client = {
            ENABLE_AUTO_REGISTRATION = true;
            UPDATE_AVATAR = true;
          };
          session.COOKIE_SECURE = true;
          other = {
            SHOW_FOOTER_VERSION = false;
            SHOW_FOOTER_TEMPLATE_LOAD_TIME = false;
          };
        };
      };

      services.homelab.caddy.virtualHosts.forgejo = {
        inherit domain;
        reverseProxy = "127.0.0.1:${toString port}";
      };

      # Pocket ID stores the client credentials. This file contains
      # FORGEJO_OIDC_CLIENT_ID and FORGEJO_OIDC_CLIENT_SECRET.
      sops.secrets.forgejo_env = {
        owner = config.services.forgejo.user;
        group = config.services.forgejo.group;
        mode = "0400";
        restartUnits = ["forgejo-pocket-id.service"];
      };

      # Forgejo stores authentication sources in its database. Reconcile the
      # PocketID source after Forgejo has initialized or migrated that database.
      systemd.services.forgejo-pocket-id = {
        description = "Configure Forgejo login through Pocket ID";
        wantedBy = ["multi-user.target"];
        after = ["forgejo.service"];
        requires = ["forgejo.service"];
        environment = {
          USER = config.services.forgejo.user;
          HOME = config.services.forgejo.stateDir;
          FORGEJO_WORK_DIR = config.services.forgejo.stateDir;
          FORGEJO_CUSTOM = config.services.forgejo.customDir;
        };
        serviceConfig = {
          Type = "oneshot";
          User = config.services.forgejo.user;
          Group = config.services.forgejo.group;
          EnvironmentFile = config.sops.secrets.forgejo_env.path;
        };
        script = ''
          set -eu

          if [ -z "''${FORGEJO_OIDC_CLIENT_ID:-}" ] || [ -z "''${FORGEJO_OIDC_CLIENT_SECRET:-}" ]; then
            echo "Skipping Pocket ID setup until forgejo_env contains client credentials." >&2
            exit 0
          fi

          auth_id="$(${forgejo} admin auth list --vertical-bars | ${pkgs.gawk}/bin/awk -F '|' '
            $2 ~ /^[[:space:]]*PocketID[[:space:]]*$/ {
              gsub(/[[:space:]]/, "", $1)
              print $1
              exit
            }
          ')"

          common_args=(
            --name PocketID
            --provider openidConnect
            --key "$FORGEJO_OIDC_CLIENT_ID"
            --secret "$FORGEJO_OIDC_CLIENT_SECRET"
            --auto-discover-url ${lib.escapeShellArg pocketIdDiscoveryUrl}
            --skip-local-2fa
            --scopes openid
            --scopes email
            --scopes profile
          )

          if [ -n "$auth_id" ]; then
            ${forgejo} admin auth update-oauth --id "$auth_id" "''${common_args[@]}"
          else
            ${forgejo} admin auth add-oauth "''${common_args[@]}"
          fi
        '';
      };
    };
  };
}
