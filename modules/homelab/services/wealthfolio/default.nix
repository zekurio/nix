{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.wealthfolio;
  domain = "wealth.${config.services.homelab.domains.zekurio}";
  port = 8088;
  hashDir = "/run/wealthfolio-auth";
in {
  options.services.homelab.wealthfolio.enable = lib.mkEnableOption "Wealthfolio investment tracker with Caddy integration";

  config = lib.mkIf cfg.enable {
    services.wealthfolio = {
      enable = true;
      address = "127.0.0.1";
      inherit port;
      secretKeyFile = config.sops.secrets.wealthfolio_secret_key.path;
      authPasswordHashFile = "${hashDir}/hash";
      # The server refuses a wildcard origin while its login is on.
      corsAllowOrigins = "https://${domain}";
      # Caddy always terminates TLS in front of the loopback listener.
      cookieSecure = "true";
      authTokenTtlMinutes = 10080;
    };

    # Wealthfolio takes its login as an Argon2id PHC string. Deriving it at
    # boot from the shared admin password keeps one password for every admin
    # UI and no second secret that can drift from it.
    systemd.services.wealthfolio-auth-hash = {
      description = "Derive the Wealthfolio login hash from the admin password";
      before = ["wealthfolio.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "wealthfolio-auth";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
      };
      script = ''
        salt=$(${lib.getExe pkgs.openssl} rand -hex 8)
        # tr strips the trailing newline sops leaves at the end of the value.
        tr -d '\n' < ${config.sops.secrets.admin_password.path} \
          | ${pkgs.libargon2}/bin/argon2 "$salt" -id -t 3 -m 16 -p 1 -e \
          > ${hashDir}/hash
      '';
    };

    systemd.services.wealthfolio = {
      # Requires= also restarts Wealthfolio when the hash unit is restarted.
      requires = ["wealthfolio-auth-hash.service"];
      after = ["wealthfolio-auth-hash.service"];
    };

    # The secret encrypts stored credentials and signs sessions. Losing it
    # loses those credentials, so it lives in sops rather than being
    # generated on the host.
    sops.secrets.wealthfolio_secret_key = {
      mode = "0400";
      restartUnits = ["wealthfolio.service"];
    };
    sops.secrets.admin_password.restartUnits = ["wealthfolio-auth-hash.service"];

    services.homelab.backup.stopUnits = ["wealthfolio.service"];

    services.homelab.caddy.virtualHosts.wealthfolio = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
