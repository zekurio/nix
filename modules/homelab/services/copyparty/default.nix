{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.copyparty;
    mediaShare = config.modules.homelab.mediaShare;
    shares = mediaShare.userShares;
    owners = lib.unique (map (share: share.owner) (lib.attrValues shares));
    uploadDir = "${mediaShare.downloadsRoot}/complete/copyparty";
    domain = "drop.${config.services.homelab.domains.zekurio}";
    port = 3923;
  in {
    options.services.homelab.copyparty.enable = lib.mkEnableOption "Copyparty private shares and music upload inbox";

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = mediaShare.enable && shares != {};
          message = "Copyparty requires configured media-share user shares.";
        }
      ];

      users.groups.copyparty = {};
      users.users.copyparty = {
        isSystemUser = true;
        group = "copyparty";
      };

      # Reuse each owner's SMB credential without copying it into the Nix store.
      sops.templates."copyparty.conf" = {
        owner = "copyparty";
        group = "copyparty";
        mode = "0400";
        restartUnits = ["copyparty.service"];
        content = ''
          [global]
            i: 127.0.0.1
            p: ${toString port}
            http-only
            no-crt
            usernames
            no-reload
            no-robots
            rproxy: 1
            xff-src: 127.0.0.0/8,::1/128
            site: https://${domain}/
            name: Files and music drop
            hist: /var/cache/copyparty
            dotpart
            xdev
            xvol

          [accounts]
          ${lib.concatMapStringsSep "\n" (owner: "  ${owner}: ${config.sops.placeholder."smb_password_${owner}"}") owners}

          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: share: ''
              [/shares/${name}]
                ${share.path}
                accs:
                  rwmd: ${share.owner}
                flags:
                  e2d
                  d2t
                  chmod_d: 770
                  chmod_f: 660
            '')
            shares)}

          [/music-drop]
            ${uploadDir}
            accs:
              rwmd: ${lib.concatStringsSep ", " owners}
            flags:
              e2d
              d2t
              rm_partial
              chmod_d: 2775
              chmod_f: 664
        '';
      };

      systemd.tmpfiles.rules = [
        "d ${uploadDir} 2775 ${mediaShare.user} ${mediaShare.group} -"
      ];

      systemd.services.copyparty = {
        description = "Copyparty private shares and music upload inbox";
        wantedBy = ["multi-user.target"];
        after = ["systemd-tmpfiles-setup.service" "mediaShare-user-library-acl.service"];
        requires = ["mediaShare-user-library-acl.service"];
        unitConfig.RequiresMountsFor = [uploadDir] ++ map (share: share.path) (lib.attrValues shares);
        environment = {
          HOME = "/var/lib/copyparty";
          XDG_CONFIG_HOME = "/var/lib/copyparty";
        };
        serviceConfig = {
          User = "copyparty";
          Group = "copyparty";
          SupplementaryGroups = [mediaShare.group];
          UMask = mediaShare.umask;
          ExecStart = "${lib.getExe pkgs.copyparty} -c ${config.sops.templates."copyparty.conf".path}";
          StateDirectory = "copyparty";
          StateDirectoryMode = "0700";
          CacheDirectory = "copyparty";
          CacheDirectoryMode = "0700";
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ReadWritePaths = [uploadDir] ++ map (share: share.path) (lib.attrValues shares);
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
        };
      };

      services.homelab.caddy.virtualHosts.copyparty = {
        inherit domain;
        # Every volume requires an account; remote users can reach their files.
        public = true;
        reverseProxy = "127.0.0.1:${toString port}";
      };
    };
  };
}
