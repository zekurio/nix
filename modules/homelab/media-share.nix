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

  mediaDatasets = [
    "tank/anime"
    "tank/movies"
    "tank/music"
    "tank/photos"
    "tank/tv"
  ];

  mediaDirs = [
    "/mnt/downloads"
    "/mnt/downloads/complete"
    "/mnt/downloads/incomplete"
    "/tank/torrents"
    "/tank/torrents/incomplete"
    "/tank/torrents/completed"
  ];

  stateDirs = [
    "/var/lib/jellyfin"
    "/var/lib/lidarr"
    "/var/lib/navidrome"
    "/var/lib/qBittorrent"
    "/var/lib/radarr"
    "/var/lib/sabnzbd"
    "/var/lib/sonarr"
  ];

  mediaDatasetMounts = map (dataset: "/${dataset}") cfg.datasets;

  managedPaths = mediaDirs ++ stateDirs ++ mediaDatasetMounts;

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

    datasets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = mediaDatasets;
      description = "ZFS datasets that should exist for media libraries.";
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

    systemd.services.media-share-zfs-datasets = {
      description = "Ensure ZFS datasets exist for media shares";
      wantedBy = [ "multi-user.target" ];
      after = [ "zfs-import.target" ];
      requires = [ "zfs-import.target" ];
      serviceConfig.Type = "oneshot";
      path = [
        config.boot.zfs.package
        pkgs.coreutils
      ];
      script = ''
        set -euo pipefail

        for dataset in ${lib.concatStringsSep " " cfg.datasets}; do
          if ! zfs list -H -o name "$dataset" >/dev/null 2>&1; then
            zfs create "$dataset"
          fi

          mountpoint="$(zfs get -H -o value mountpoint "$dataset")"
          if [ "$mountpoint" = "legacy" ] || [ "$mountpoint" = "-" ]; then
            continue
          fi

          install -d -m 2775 -o ${shareUser} -g ${shareGroup} "$mountpoint"
        done
      '';
    };

    systemd.services.media-share-prepare = {
      description = "Ensure media directories exist for shared services";
      wantedBy = [ "multi-user.target" ];
      after = [
        "local-fs.target"
        "media-share-zfs-datasets.service"
      ];
      requires = [ "media-share-zfs-datasets.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        for dir in ${lib.concatStringsSep " " managedPaths}; do
          ${pkgs.coreutils}/bin/install -d -m 2775 -o ${shareUser} -g ${shareGroup} "$dir"
        done
      '';
    };
  };
}
