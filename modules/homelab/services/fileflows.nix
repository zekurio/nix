{
  config,
  lib,
  ...
}: let
  cfg = config.services.fileflows-wrapped;
  shareUser = "share";
  shareGroup = "share";
  tempPath = "/tmp/fileflows";
  shareUidValue =
    lib.attrByPath ["users" "users" shareUser "uid"] null config;
  shareGidValue =
    lib.attrByPath ["users" "groups" shareGroup "gid"] null config;
  shareUidStr =
    let
      t = builtins.typeOf shareUidValue;
    in
      if t == "int" || t == "string"
      then builtins.toString shareUidValue
      else null;
  shareGidStr =
    let
      t = builtins.typeOf shareGidValue;
    in
      if t == "int" || t == "string"
      then builtins.toString shareGidValue
      else null;
  envBase =
    {
      TempPathHost = tempPath;
      UMASK = "0002";
    }
    // lib.optionalAttrs (shareUidStr != null) { PUID = shareUidStr; }
    // lib.optionalAttrs (shareGidStr != null) { PGID = shareGidStr; };
  shareUserOption =
    lib.optional
    (shareUidStr != null && shareGidStr != null)
    "--user=${shareUidStr}:${shareGidStr}";
in {
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
      default = "revenz/fileflows:latest";
      description = "Container image to run for FileFlows";
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
      "d ${tempPath} 2775 ${shareUser} ${shareGroup} -"
    ];

    virtualisation.oci-containers.containers.fileflows = {
      image = cfg.image;
      autoStart = true;
      ports = ["${toString cfg.port}:5000"];
      environment = envBase;
      volumes = [
        "fileflows-data:/app/Data"
        "fileflows-logs:/app/Logs"
        "${tempPath}:/temp"
        "/var/downloads/completed:/completed"
        "/var/downloads/converted:/converted"
        "/mnt/fast-nvme/media:/media"
        "/run/podman/podman.sock:/var/run/docker.sock:ro"
      ];
      extraOptions =
        [
          "--device=/dev/dri:/dev/dri"
        ]
        ++ shareUserOption;
    };

    services.caddy-wrapper.virtualHosts."fileflows" = {
      domain = cfg.domain;
      extraConfig =
        lib.optionalString (cfg.basicAuthUsers != {}) ''
          basicauth {
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (user: hash: "  ${user} ${hash}") cfg.basicAuthUsers)}
          }
        '';
      reverseProxy = "localhost:${toString cfg.port}";
    };
  };
}
