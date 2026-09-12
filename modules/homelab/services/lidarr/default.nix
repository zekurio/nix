{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.lidarr;
    mediaShare = config.modules.homelab.mediaShare;
    domain = "admin.${config.services.homelab.domains.zekurio}";
    port = 8686;
    tubifarry = pkgs.stdenvNoCC.mkDerivation {
      pname = "tubifarry";
      version = "2.1.1";
      src = pkgs.fetchurl {
        url = "https://github.com/TypNull/Tubifarry/releases/download/v2.1.1/Tubifarry-v2.1.1.net8.0.zip";
        hash = "sha256-G1y+Ps/xn6OsvlVeVGSkzXTJkS+qqYarjsN9xj3Sfps=";
      };
      nativeBuildInputs = [pkgs.unzip];
      dontUnpack = true;
      dontStrip = true;
      installPhase = ''
        mkdir -p "$out"
        unzip "$src" -d "$out"
      '';
    };
  in {
    options.services.homelab.lidarr = {
      enable = lib.mkEnableOption "Lidarr music manager with Tubifarry and Caddy integration";
      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:${toString port}/lidarr";
        description = "URL other services use to reach the Lidarr API.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.homelab.slskd.enable && config.services.homelab.prowlarr.enable && config.services.homelab.configarr.enable && config.services.homelab.sabnzbd.enable;
          message = "Lidarr's music integrations require slskd, Prowlarr, Configarr and SABnzbd.";
        }
      ];

      services.lidarr = {
        enable = true;
        package = pkgs.callPackage ./_package.nix {};
        dataDir = "/var/lib/lidarr";
        environmentFiles = [config.sops.templates."lidarr.env".path];
        settings = {
          server = {
            bindAddress = "127.0.0.1";
            urlBase = "/lidarr";
            inherit port;
          };
          auth.method = "Forms";
          update = {
            automatically = false;
            mechanism = "external";
          };
        };
      };

      sops.secrets.lidarr_api_key = {};
      sops.secrets.sabnzbd_api_key = {};
      system.checks = [
        (pkgs.runCommand "lidarr-config-check" {
            nativeBuildInputs = [(pkgs.python3.withPackages (p: [p.pyyaml]))];
          } ''
            PYTHONPATH=${./.} python ${./check.py} ${../configarr/templates/lidarr.yml}
            touch "$out"
          '')
      ];
      sops.templates."lidarr.env" = {
        content = ''
          LIDARR__AUTH__APIKEY=${config.sops.placeholder.lidarr_api_key}
        '';
        restartUnits = ["lidarr.service" "configarr.service" "lidarr-integrations.service"];
      };

      systemd.services.lidarr = {
        unitConfig.RequiresMountsFor = [mediaShare.musicDir mediaShare.downloadsRoot];
        path = [pkgs.ffmpeg];
        # Tubifarry attempts updates at startup. The store link keeps the plugin
        # pinned even when its updater incorrectly offers the installed version.
        preStart = ''
          mkdir -p ${config.services.lidarr.dataDir}/plugins/TypNull
          ln -sfn ${tubifarry} ${config.services.lidarr.dataDir}/plugins/TypNull/Tubifarry
        '';
        serviceConfig = {
          SupplementaryGroups = [mediaShare.group];
          UMask = lib.mkForce mediaShare.umask;
        };
      };

      systemd.services.lidarr-integrations = {
        description = "Configure Lidarr's Soulseek indexer and Prowlarr sync";
        wantedBy = ["multi-user.target"];
        requires = ["lidarr.service" "prowlarr.service" "slskd.service"];
        after = ["lidarr.service" "prowlarr.service" "slskd.service"];
        before = ["configarr.service"];
        environment = {
          LIDARR_URL = cfg.baseUrl;
          PROWLARR_URL = "http://127.0.0.1:9696/prowlarr";
          SLSKD_URL = "http://127.0.0.1:5030/slskd";
        };
        serviceConfig = {
          Type = "oneshot";
          DynamicUser = true;
          LoadCredential = [
            "lidarr-api-key:${config.sops.secrets.lidarr_api_key.path}"
            "slskd-api-key:${config.sops.secrets.slskd_api_key.path}"
            "prowlarr-config:${config.services.prowlarr.dataDir}/config.xml"
          ];
          ExecStart = "${lib.getExe pkgs.python3} ${./provision.py}";
          Restart = "on-failure";
          RestartSec = "30s";
          TimeoutStartSec = "5min";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
        };
      };

      services.homelab.caddy.virtualHosts.lidarr = {
        inherit domain;
        extraConfig = ''
          redir /lidarr /lidarr/
          @lidarr path /lidarr*
          reverse_proxy @lidarr 127.0.0.1:${toString port}
        '';
      };
    };
  };
}
