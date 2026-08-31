{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.copyparty;
    mediaShare = config.modules.homelab.mediaShare;
    serviceUser = "copyparty";
    serviceGroup = "copyparty";
    adminUser = "zekurio";
    adminGroup = "homelab-admin";
    stateDir = "/var/lib/copyparty";
    cacheDir = "/var/cache/copyparty";
    runtimeConfig = "/run/copyparty/copyparty.conf";
    uploadDir = "${mediaShare.downloadsRoot}/complete/copyparty";
    domain = "drop.${config.services.homelab.domains.zekurio}";
    port = 3923;

    configTemplate = pkgs.writeText "copyparty.conf" ''
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
        name: Beets drop
        hist: ${cacheDir}
        dotpart

      [accounts]
        ${adminUser}: {{admin-password}}

      [/]
        ${uploadDir}
        accs:
          rwmd: ${adminUser}
        flags:
          e2d
          d2t
          # Expired resumable uploads must not block the Beets worker forever.
          rm_partial
          chmod_d: 2775
          chmod_f: 664
    '';
  in {
    options.services.homelab.copyparty = {
      enable = lib.mkEnableOption "Copyparty upload inbox for Beets";
    };

    config = lib.mkIf cfg.enable {
      users.groups.${serviceGroup} = {};
      users.users.${serviceUser} = {
        isSystemUser = true;
        group = serviceGroup;
        home = stateDir;
        description = "Copyparty file upload service";
      };

      systemd.tmpfiles.rules = [
        "d ${uploadDir} 2775 ${mediaShare.user} ${mediaShare.group} -"
      ];

      systemd.services.copyparty = {
        description = "Copyparty Beets upload inbox";
        wantedBy = ["multi-user.target"];
        after = [
          "local-fs.target"
          "systemd-tmpfiles-setup.service"
        ];
        requires = ["systemd-tmpfiles-setup.service"];
        unitConfig.RequiresMountsFor = uploadDir;
        environment = {
          HOME = stateDir;
          PYTHONUNBUFFERED = "true";
          XDG_CONFIG_HOME = stateDir;
        };
        preStart = ''
          install -m 0600 ${configTemplate} ${runtimeConfig}
          ${lib.getExe pkgs.replace-secret} \
            '{{admin-password}}' \
            ${lib.escapeShellArg config.sops.secrets.admin_password.path} \
            ${runtimeConfig}
        '';
        serviceConfig = {
          Type = "simple";
          User = serviceUser;
          Group = serviceGroup;
          SupplementaryGroups = [
            adminGroup
            mediaShare.group
          ];
          UMask = lib.mkForce mediaShare.umask;
          ExecStart = "${lib.getExe pkgs.copyparty} -c ${runtimeConfig}";
          RuntimeDirectory = "copyparty";
          RuntimeDirectoryMode = "0700";
          StateDirectory = "copyparty";
          StateDirectoryMode = "0700";
          CacheDirectory = "copyparty";
          CacheDirectoryMode = "0700";
          LimitNOFILE = 4096;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          ReadWritePaths = [
            stateDir
            cacheDir
            uploadDir
          ];
        };
      };

      # This endpoint is deliberately public. Copyparty requires the shared
      # admin username and password before exposing or accepting any files.
      services.homelab.caddy.virtualHosts."copyparty" = {
        inherit domain;
        public = true;
        reverseProxy = "127.0.0.1:${toString port}";
      };
    };
  };
}
