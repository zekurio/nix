{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.modules.homelab.mediaShare;

  shareUser = "share";
  shareGroup = "share";
  shareUmask = "0002";
  shareUid = 995;
  shareGid = 995;

  mediaDirs = [
    "/tank/jellyfin/anime"
    "/tank/jellyfin/movies"
    "/tank/jellyfin/tv"
    "/mnt/downloads"
    "/mnt/downloads/complete"
    "/mnt/downloads/complete/radarr"
    "/mnt/downloads/complete/sonarr"
    "/mnt/downloads/converted"
    "/mnt/downloads/converted/radarr"
    "/mnt/downloads/converted/sonarr"
    "/mnt/downloads/incomplete"
    "/tank/jellyfin/torrents"
    "/tank/jellyfin/torrents/incomplete"
    "/tank/jellyfin/torrents/complete"
  ];

  stateDirs = [
    "/var/lib/jellyfin"
    "/var/lib/qBittorrent"
    "/var/lib/radarr"
    "/var/lib/sabnzbd"
    "/var/lib/sonarr"
  ];

  managedPaths = mediaDirs ++ stateDirs;

  directoryRules = map
    (dir: "d ${dir} 2775 ${shareUser} ${shareGroup} -")
    (mediaDirs ++ stateDirs);
in
{
  options.modules.homelab.mediaShare = {
    enable =
      lib.mkEnableOption "Shared system account and directory management for homelab media workloads";

    collaborators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Regular users that should be added to the shared media group.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = shareUser;
      readOnly = true;
      description = "Username used by media services.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = shareGroup;
      readOnly = true;
      description = "Primary group used by media services.";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = shareUid;
      readOnly = true;
      description = "Numeric UID assigned to the shared media user.";
    };

    gid = lib.mkOption {
      type = lib.types.int;
      default = shareGid;
      readOnly = true;
      description = "Numeric GID assigned to the shared media group.";
    };

    umask = lib.mkOption {
      type = lib.types.str;
      default = shareUmask;
      readOnly = true;
      description = "Default umask applied to media services.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${shareGroup} = {
      gid = cfg.gid;
    };

    users.users = lib.mkMerge [
      {
        ${shareUser} = {
          isSystemUser = true;
          group = shareGroup;
          home = "/var/lib/share";
          createHome = true;
          description = "Shared service account for media automation";
          uid = cfg.uid;
          extraGroups = [
            "video"
            "render"
          ];
        };
      }
      (lib.genAttrs cfg.collaborators (_: {
        extraGroups = lib.mkAfter [ shareGroup ];
      }))
    ];

    systemd.tmpfiles.rules = directoryRules;

    systemd.services.media-share-prepare = {
      description = "Ensure media directories exist for shared services";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        for dir in ${lib.concatStringsSep " " managedPaths}; do
          ${pkgs.coreutils}/bin/install -d -m 2775 -o ${shareUser} -g ${shareGroup} "$dir"
        done
      '';
    };
  };
}
