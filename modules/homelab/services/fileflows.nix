{ config
, lib
, ...
}:
let
  cfg = config.services.fileflows-wrapped;
  tempPath = "/tmp/fileflows";
  dataPath = "/var/lib/fileflows/data";
  logsPath = "/var/lib/fileflows/logs";
  envBase =
    {
      TempPathHost = tempPath;
      UMASK = cfg.umask;
    };
in
{
    options.services.fileflows-wrapped = {
    enable =
      lib.mkEnableOption "FileFlows media automation service wrapped with Podman and Caddy integration";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "ff.schnitzelflix.xyz";
      description = "Domain name for FileFlows";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = "Host port for the FileFlows web UI";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "revenz/fileflows:25.11";
      description = "Container image to run for FileFlows";
    };

    umask = lib.mkOption {
      type = lib.types.str;
      default = "0002";
      description = "Umask applied inside the FileFlows container.";
    };

    basicAuthUsers = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        admin = "$2a$14$c2HVFsuYsy1wGyGZFde9QOAN9SdcX6d5j9iBfL0MFU5FVcoB0.1sK";
      };
      description = "Map of usernames to bcrypt hashed passwords for securing the FileFlows UI.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/fileflows 2775 root root -"
      "d ${dataPath} 2775 root root -"
      "d ${logsPath} 2775 root root -"
      "d ${tempPath} 2775 root root -"
    ];

    virtualisation.oci-containers.containers.fileflows =
      {
        image = cfg.image;
        autoStart = true;
        ports = [ "${toString cfg.port}:5000" ];
        environment = envBase;
        volumes = [
          "${dataPath}:/app/Data"
          "${logsPath}:/app/Logs"
          "${tempPath}:/temp"
          "/mnt/downloads/completed:/mnt/downloads/completed"
          "/mnt/downloads/converted:/mnt/downloads/converted"
          "/run/podman/podman.sock:/var/run/docker.sock:ro"
        ];
        extraOptions = [
          "--device=/dev/dri:/dev/dri"
        ];
      };

    services.caddy-wrapper.virtualHosts."fileflows" = {
      domain = cfg.domain;
      extraConfig =
        lib.optionalString (cfg.basicAuthUsers != { }) ''
          basicauth {
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (user: hash: "  ${user} ${hash}") cfg.basicAuthUsers)}
          }
        '';
      reverseProxy = "localhost:${toString cfg.port}";
    };
  };
}
