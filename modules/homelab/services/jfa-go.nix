{ config
, lib
, ...
}:
let
  cfg = config.services.jfa-go-wrapped;
  shareUser = "share";
  shareGroup = "share";
  dataPath = cfg.dataDir;
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
  envBase =
    lib.optionalAttrs (config.time.timeZone != null) { TZ = config.time.timeZone; }
    // lib.optionalAttrs (shareUidStr != null) { PUID = shareUidStr; }
    // lib.optionalAttrs (shareGidStr != null) { PGID = shareGidStr; };
  baseVolumes =
    [
      "${dataPath}:/data"
      "/etc/localtime:/etc/localtime:ro"
    ]
    ++ lib.optional (cfg.jellyfinPath != null) "${cfg.jellyfinPath}:/jf";
in
{
  options.services.jfa-go-wrapped = {
    enable =
      lib.mkEnableOption "jfa-go invitation manager wrapped with Podman and Caddy integration";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "accounts.schnitzelflix.xyz";
      description = "Domain name for jfa-go";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8056;
      description = "Host port for the jfa-go web UI";
    };

    tlsPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = "Optional host port for the TLS listener exposed by jfa-go";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "hrfee/jfa-go:unstable";
      description = "Container image to run for jfa-go";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/jfa-go";
      description = "Directory to persist jfa-go configuration and data";
    };

    jellyfinPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "/var/lib/jellyfin";
      description = "Mount point for Jellyfin data to support password resets; set to null to disable";
    };

    extraVolumes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional Podman volume bindings";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables for the jfa-go container";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${dataPath} 2775 ${shareUser} ${shareGroup} -"
    ];

    virtualisation.oci-containers.containers."jfa-go" = {
      image = cfg.image;
      autoStart = true;
      ports =
        [ "${toString cfg.port}:8056" ]
        ++ lib.optional (cfg.tlsPort != null) "${toString cfg.tlsPort}:8057";
      environment = envBase // cfg.extraEnvironment;
      volumes = baseVolumes ++ cfg.extraVolumes;
    };

    services.caddy-wrapper.virtualHosts."jfa-go" = {
      domain = cfg.domain;
      reverseProxy = "localhost:${toString cfg.port}";
    };
  };
}
