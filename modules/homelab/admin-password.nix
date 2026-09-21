{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    adminGroup = "homelab-admin";
    adminUsername = "zekurio";
    adminPassword = config.sops.secrets.admin_password.path;

    # Servarr stores Web UI users in SQLite rather than its environment-backed
    # host settings. Match UserService's PBKDF2 parameters and wait for fresh
    # installations to finish creating the schema before provisioning.
    provisionServarrAuth = pkgs.writeShellScript "servarr-provision-admin-auth" ''
      ${pkgs.python3}/bin/python3 - "$@" <<'PY'
      import base64
      import hashlib
      import hmac
      import os
      import sqlite3
      import sys
      import time
      import uuid

      database, password_file, username = sys.argv[1:]
      deadline = time.monotonic() + 60
      while True:
          if os.path.exists(database):
              with sqlite3.connect(database) as connection:
                  users_table = connection.execute(
                      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'Users'"
                  ).fetchone()
              if users_table is not None:
                  break
          if time.monotonic() >= deadline:
              raise TimeoutError(f"Users table was not created in {database}")
          time.sleep(1)

      with sqlite3.connect(database) as connection:
          with open(password_file, "rb") as handle:
              password = handle.read().rstrip(b"\r\n")
          if not password:
              raise ValueError("admin password must not be empty")

          user = connection.execute(
              'SELECT "Id", "Username", "Password", "Salt", "Iterations" '
              'FROM "Users" ORDER BY "Id" LIMIT 1'
          ).fetchone()
          if user is not None:
              user_id, current_username, current_hash, current_salt, iterations = user
              if current_salt and iterations:
                  expected_hash = base64.b64encode(
                      hashlib.pbkdf2_hmac(
                          "sha512", password, base64.b64decode(current_salt), iterations, 32
                      )
                  ).decode()
                  if current_username == username and hmac.compare_digest(
                      current_hash, expected_hash
                  ):
                      sys.exit()

          iterations = 10000
          salt = os.urandom(16)
          password_hash = base64.b64encode(
              hashlib.pbkdf2_hmac("sha512", password, salt, iterations, 32)
          ).decode()
          salt = base64.b64encode(salt).decode()

          if user is None:
              connection.execute(
                  'INSERT INTO "Users" '
                  '("Identifier", "Username", "Password", "Salt", "Iterations") '
                  'VALUES (?, ?, ?, ?, ?)',
                  (str(uuid.uuid4()), username, password_hash, salt, iterations),
              )
          else:
              connection.execute(
                  'UPDATE "Users" SET "Username" = ?, "Password" = ?, '
                  '"Salt" = ?, "Iterations" = ? WHERE "Id" = ?',
                  (username, password_hash, salt, iterations, user_id),
              )
      PY
    '';

    mkServarrAuth = database: {
      postStart = lib.mkAfter ''
        ${provisionServarrAuth} ${lib.escapeShellArgs [database adminPassword adminUsername]}
      '';
      serviceConfig.SupplementaryGroups = [adminGroup];
    };
  in {
    users.groups.homelab-admin = {};

    sops.secrets.admin_password = {
      group = adminGroup;
      mode = "0440";
      restartUnits = [
        "prowlarr.service"
        "radarr.service"
        "sabnzbd.service"
        "slskd.service"
        "sonarr.service"
      ];
    };

    sops.templates."slskd-admin.env" = lib.mkIf config.services.homelab.slskd.enable {
      content = ''
        SLSKD_USERNAME=${adminUsername}
        SLSKD_PASSWORD=${config.sops.placeholder.admin_password}
      '';
      owner = "slskd";
      group = "slskd";
      mode = "0400";
    };

    systemd.services = lib.mkMerge [
      (lib.mkIf config.services.homelab.slskd.enable {
        slskd.serviceConfig.EnvironmentFile = lib.mkAfter [
          config.sops.templates."slskd-admin.env".path
        ];
      })
      (lib.mkIf config.services.homelab.sonarr.enable {
        sonarr = mkServarrAuth "${config.services.sonarr.dataDir}/sonarr.db";
      })
      (lib.mkIf config.services.homelab.radarr.enable {
        radarr = mkServarrAuth "${config.services.radarr.dataDir}/radarr.db";
      })
      (lib.mkIf config.services.homelab.prowlarr.enable {
        prowlarr = mkServarrAuth "${config.services.prowlarr.dataDir}/prowlarr.db";
      })
    ];
  };
}
