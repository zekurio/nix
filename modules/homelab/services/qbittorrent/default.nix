{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.qbittorrent;
    mediaShare = config.modules.homelab.mediaShare;
    downloadsRoot = mediaShare.torrentDownloadsRoot;
    domain = "admin.${config.services.homelab.domains.zekurio}";
    webuiPort = 8080;
    webuiPassword = config.sops.secrets.admin_password.path;

    configureWebuiAuth = pkgs.writeShellScript "qbittorrent-configure-webui-auth" ''
      set -euo pipefail

      config_file=/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf
      password_hash="$(${pkgs.python3}/bin/python3 -c \
        'import base64, hashlib, os, sys; password = open(sys.argv[1], "rb").read().rstrip(b"\r\n"); salt = os.urandom(16); digest = hashlib.pbkdf2_hmac("sha512", password, salt, 100000, 64); print(f"@ByteArray({base64.b64encode(salt).decode()}:{base64.b64encode(digest).decode()})")' \
        ${lib.escapeShellArg webuiPassword})"

      ${pkgs.gnused}/bin/sed -i \
        -e '/^WebUI\\Username=/d' \
        -e '/^WebUI\\Password_PBKDF2=/d' \
        "$config_file"
      ${pkgs.coreutils}/bin/printf '%s=%s\n%s="%s"\n' \
        'WebUI\Username' zekurio \
        'WebUI\Password_PBKDF2' "$password_hash" >> "$config_file"
    '';
  in {
    options.services.homelab.qbittorrent.enable = lib.mkEnableOption "qBittorrent client";

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = mediaShare.enable;
          message = "services.homelab.qbittorrent requires modules.homelab.mediaShare.";
        }
      ];

      services.qbittorrent = {
        enable = true;
        inherit webuiPort;
        torrentingPort = 1337;
        extraArgs = ["--confirm-legal-notice"];
        serverConfig = {
          LegalNotice.Accepted = true;
          BitTorrent.Session = {
            DefaultSavePath = "${downloadsRoot}/complete";
            GlobalMaxSeedingMinutes = 10 * 24 * 60;
            TempPath = "${downloadsRoot}/incomplete";
            TempPathEnabled = true;
          };
          Preferences = {
            Connection.UPnP = false;
            WebUI = {
              Address = "127.0.0.1";
              CSRFProtection = true;
              ClickjackingProtection = true;
              HostHeaderValidation = true;
              LocalHostAuth = true;
              ServerDomains = domain;
              UPnP = false;
            };
          };
        };
      };

      systemd.services.qbittorrent = {
        unitConfig.RequiresMountsFor = [
          downloadsRoot
          webuiPassword
        ];
        serviceConfig = {
          ExecStartPre = lib.mkAfter [configureWebuiAuth];
          SupplementaryGroups = [
            mediaShare.group
            config.sops.secrets.admin_password.group
          ];
          UMask = lib.mkForce mediaShare.umask;
        };
      };

      services.homelab.caddy.virtualHosts.qbittorrent = {
        inherit domain;
        extraConfig = ''
          redir /qbittorrent /qbittorrent/
          handle_path /qbittorrent/* {
            reverse_proxy 127.0.0.1:${toString webuiPort} {
              header_up X-Forwarded-Host {http.request.host}
            }
          }
        '';
      };
    };
  };
}
