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
    dataDir = config.services.lidarr.dataDir;
    slskdPlugin = pkgs.stdenvNoCC.mkDerivation {
      pname = "lidarr-plugin-slskd";
      version = "1.1.4.0";
      src = pkgs.fetchurl {
        url = "https://github.com/allquiet-hub/Lidarr.Plugin.Slskd/releases/download/v1.1.4.0/Lidarr.Plugin.Slskd.net8.0.zip";
        hash = "sha256-l2Yf8K+xnpC/p8a16NOadt3bJ1eaBOlArHR7vFaC5CE=";
      };
      nativeBuildInputs = [pkgs.unzip];
      dontUnpack = true;
      installPhase = ''
        mkdir -p "$out"
        unzip "$src" -d "$out"
      '';
    };
  in {
    options.services.homelab.lidarr = {
      enable = lib.mkEnableOption "Lidarr music manager with beets and slskd";
      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:${toString port}/lidarr";
        description = "URL other services use to reach the Lidarr API.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = mediaShare.enable;
          message = "Lidarr requires the shared media directories and group.";
        }
        {
          assertion = config.services.homelab.beets.enable && config.services.homelab.slskd.enable;
          message = "Lidarr requires the homelab beets and slskd services.";
        }
        {
          assertion = lib.versionAtLeast config.services.slskd.package.version "0.26.0";
          message = "The Lidarr slskd plugin requires slskd >= 0.26.0 for its batch API.";
        }
      ];

      services.lidarr = {
        enable = true;
        package = pkgs.callPackage ./_package.nix {};
        settings = {
          server = {
            urlBase = "/lidarr";
            bindAddress = "127.0.0.1";
          };
          auth.method = "Forms";
          update.branch = "develop";
        };
        environmentFiles = [config.sops.templates."lidarr.env".path];
      };

      system.checks = [
        (pkgs.runCommand "lidarr-integration-check" {nativeBuildInputs = [pkgs.python3];} ''
          python ${./test-integration.py} \
            --lidarr ${lib.getExe config.services.lidarr.package} \
            --plugin ${slskdPlugin} \
            --configure ${./configure.py} \
            --script ${pkgs.coreutils}/bin/true
          touch "$out"
        '')
      ];

      sops = {
        secrets.lidarr_api_key = {};
        templates."lidarr.env" = {
          content = ''
            LIDARR__AUTH__APIKEY=${config.sops.placeholder.lidarr_api_key}
            SLSKD_API_KEY=${config.sops.placeholder.slskd_api_key}
          '';
          owner = "lidarr";
          group = "lidarr";
          mode = "0400";
          restartUnits = ["lidarr.service"];
        };
      };

      systemd.services.lidarr = {
        after = ["slskd.service"];
        wants = ["slskd.service"];
        unitConfig.RequiresMountsFor = [mediaShare.musicDir mediaShare.downloadsRoot];
        serviceConfig = {
          SupplementaryGroups = [mediaShare.group];
          UMask = lib.mkForce mediaShare.umask;
          TimeoutStartSec = "5min";
        };
        preStart = ''
          mkdir -p ${lib.escapeShellArg "${dataDir}/plugins/allquiet-hub"}
          ln -sfnT ${slskdPlugin} ${lib.escapeShellArg "${dataDir}/plugins/allquiet-hub/Lidarr.Plugin.Slskd"}
        '';
        postStart = ''
          ${lib.getExe pkgs.python3} ${./configure.py} \
            --url ${lib.escapeShellArg cfg.baseUrl} \
            --music-dir ${lib.escapeShellArg mediaShare.musicDir} \
            --beets-script ${lib.escapeShellArg (lib.getExe config.services.homelab.beets.lidarrHook)} \
            --slskd-url ${lib.escapeShellArg "http://127.0.0.1:${toString config.services.slskd.settings.web.port}${config.services.slskd.settings.web.url_base}"} \
            --slskd-external-url ${lib.escapeShellArg "https://${domain}/slskd/"}
        '';
      };

      services.homelab.caddy.virtualHosts.lidarr = {
        inherit domain;
        extraConfig = ''
          redir /lidarr /lidarr/
          @lidarr path /lidarr*
          reverse_proxy @lidarr 127.0.0.1:${toString port} {
            header_up Host {http.request.host}
            header_up X-Forwarded-Prefix /lidarr
          }
        '';
      };
    };
  };
}
