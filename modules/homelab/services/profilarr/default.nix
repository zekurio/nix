{
  config,
  lib,
  ...
}: let
  cfg = config.services.homelab.profilarr;
  domain = "arr.schnitzelflix.xyz";
  port = 6868;
  parserPort = 5000;
  dataDir = "/var/lib/profilarr";
in {
  options.services.homelab.profilarr = {
    enable = lib.mkEnableOption "Profilarr configuration management with parser container and Caddy integration";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/dictionarry-hub/profilarr:latest";
      description = "Profilarr container image to run.";
    };

    parserImage = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/dictionarry-hub/profilarr-parser:latest";
      description = "Profilarr parser container image to run.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers = {
      profilarr = {
        image = cfg.image;
        autoStart = true;
        dependsOn = ["profilarr-parser"];
        extraOptions = ["--network=host"];

        environment = {
          PUID = "1000";
          PGID = "1000";
          UMASK = "022";
          TZ = config.time.timeZone;
          PORT = toString port;
          HOST = "127.0.0.1";
          AUTH = "off";
          ORIGIN = "https://${domain}/profilarr";
          PARSER_HOST = "127.0.0.1";
          PARSER_PORT = toString parserPort;
        };

        volumes = [
          "${dataDir}/config:/config"
        ];
      };

      profilarr-parser = {
        image = cfg.parserImage;
        autoStart = true;
        extraOptions = ["--network=host"];
      };
    };

    systemd.tmpfiles.rules = [
      "d ${dataDir} 0755 1000 1000 -"
      "d ${dataDir}/config 0755 1000 1000 -"
    ];

    services.homelab.caddy.virtualHosts."profilarr" = {
      inherit domain;
      forwardAuth = "127.0.0.1:4180";
      extraConfig = ''
        redir /profilarr /profilarr/
        @profilarr path /profilarr*
        handle @profilarr {
          uri strip_prefix /profilarr
          reverse_proxy 127.0.0.1:${toString port} {
            header_up Host {http.request.host}
            header_up X-Forwarded-Prefix /profilarr
          }
        }
      '';
    };
  };
}
