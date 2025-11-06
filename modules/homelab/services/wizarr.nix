{ config
, lib
, ...
}:
let
  cfg = config.services.wizarr-wrapped;
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
    // lib.optionalAttrs (shareGidStr != null) { PGID = shareGidStr; }
    // {
      DISABLE_BUILTIN_AUTH = if cfg.disableBuiltinAuth then "true" else "false";
    };
  baseVolumes =
    [
      "${dataPath}:/data"
      "/etc/localtime:/etc/localtime:ro"
    ];
in
{
  options.services.wizarr-wrapped = {
    enable =
      lib.mkEnableOption "wizarr invitation portal wrapped with Podman and Caddy integration";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "accounts.schnitzelflix.xyz";
      description = "Domain name for Wizarr";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5690;
      description = "Host port for the Wizarr web UI";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/wizarrrr/wizarr:latest";
      description = "Container image to run for Wizarr";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/wizarr";
      description = "Directory to persist Wizarr configuration and data";
    };

    disableBuiltinAuth = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Disable builtin Wizarr authentication when using external auth providers.";
    };

    extraVolumes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional Podman volume bindings.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables for the Wizarr container.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${dataPath} 2775 ${shareUser} ${shareGroup} -"
    ];

    virtualisation.oci-containers.containers."wizarr" = {
      image = cfg.image;
      autoStart = true;
      ports = [ "${toString cfg.port}:5690" ];
      environment = envBase // cfg.extraEnvironment;
      volumes = baseVolumes ++ cfg.extraVolumes;
    };

    services.caddy-wrapper.virtualHosts."wizarr" = {
      domain = cfg.domain;
      reverseProxy = "localhost:${toString cfg.port}";
    };
  };
}
