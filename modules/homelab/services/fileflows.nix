{ config
, lib
, ...
}:
let
  cfg = config.services.fileflows-wrapped;
  mediaShare = config.modules.homelab.mediaShare;
  shareUser = mediaShare.user;
  shareGroup = mediaShare.group;

  shareUidValue =
    lib.attrByPath [ "users" "users" shareUser "uid" ] null config;
  shareGidValue =
    lib.attrByPath [ "users" "groups" shareGroup "gid" ] null config;

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

  envVars =
    {
      TempPathHost = "/temp";
      UMASK = mediaShare.umask;
    }
    // lib.optionalAttrs (shareUidStr != null) { PUID = shareUidStr; }
    // lib.optionalAttrs (shareGidStr != null) { PGID = shareGidStr; };
in
{
  options.services.fileflows-wrapped = {
    enable = lib.mkEnableOption "FileFlows media automation service with Caddy integration";

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

    tempDir = lib.mkOption {
      type = lib.types.str;
      default = "/tmp/fileflows";
      description = ''
        Host directory for temporary transcoding files.
        Defaults to /tmp/fileflows for automatic cleanup on reboot.
        For best performance, ensure /tmp is mounted as tmpfs.
      '';
    };

    basicAuthUsers = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        admin = "$2a$14$c2HVFsuYsy1wGyGZFde9QOAN9SdcX6d5j9iBfL0MFU5FVcoB0.1sK";
      };
      description = "Map of usernames to bcrypt hashed passwords for securing the FileFlows UI.";
    };

    volumes = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        "/mnt/downloads/completed" = "/completed";
        "/mnt/downloads/converted" = "/converted";
        "/mnt/downloads/incomplete" = "/incomplete";
        "/tank/media" = "/media";
      };
      example = {
        "/path/to/completed" = "/completed";
        "/path/to/converted" = "/converted";
        "/path/to/media" = "/media";
      };
      description = "Host path to container path mappings for FileFlows media volumes.";
    };

    enableHardwareAcceleration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable hardware acceleration by passing through /dev/dri devices.";
    };

    enableDockerSocket = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Docker socket access for container-based processing nodes.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create Docker volumes and temporary directory (tmpfs for transcoding cache)
    systemd.tmpfiles.rules = [
      "d /var/lib/fileflows 2775 ${shareUser} ${shareGroup} -"
      "d ${cfg.tempDir} 2775 ${shareUser} ${shareGroup} -"
    ];

    # Add share user to docker group if Docker socket access is enabled
    users.users.${shareUser} = lib.mkIf cfg.enableDockerSocket {
      extraGroups = lib.mkAfter [ "docker" ];
    };

    virtualisation.oci-containers.containers.fileflows = {
      image = cfg.image;
      autoStart = true;
      ports = [ "${toString cfg.port}:5000" ];
      environment = envVars;
      volumes =
        [
          "fileflows-data:/app/Data"
          "fileflows-logs:/app/Logs"
          "${cfg.tempDir}:/temp"
        ]
        ++ (lib.mapAttrsToList (host: container: "${host}:${container}") cfg.volumes)
        ++ lib.optional cfg.enableDockerSocket "/run/podman/podman.sock:/var/run/docker.sock:ro";
      extraOptions =
        lib.optional cfg.enableHardwareAcceleration "--device=/dev/dri:/dev/dri";
    };

    # Ensure FileFlows service runs with correct user context
    systemd.services.podman-fileflows = {
      serviceConfig = {
        User = lib.mkForce shareUser;
        Group = lib.mkForce shareGroup;
        UMask = lib.mkForce mediaShare.umask;
      };
    };

    services.caddy-wrapper.virtualHosts."fileflows" = {
      domain = cfg.domain;
      extraConfig =
        lib.optionalString (cfg.basicAuthUsers != { }) ''
          basicauth {
            ${lib.concatStringsSep "\n    " (lib.mapAttrsToList (user: hash: "${user} ${hash}") cfg.basicAuthUsers)}
          }
        '';
      reverseProxy = "localhost:${toString cfg.port}";
    };
  };
}
