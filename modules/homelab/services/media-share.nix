{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.homelab.mediaShare;

  shareUser = "share";
  shareGroup = "share";
  shareUid = 995;
  shareGid = 995;

  mediaDirs = [
    "/tank/jellyfin/anime"
    "/tank/jellyfin/movies"
    "/tank/jellyfin/music"
    "/tank/jellyfin/tv"
    "/mnt/downloads"
    "/mnt/downloads/complete"
    "/mnt/downloads/complete/lidarr"
    "/mnt/downloads/complete/radarr"
    "/mnt/downloads/complete/sonarr"
    "/mnt/downloads/incomplete"
  ];

  stateDirs = [
    "/var/lib/jellyfin"
    "/var/lib/lidarr"
    "/var/lib/radarr"
    "/var/lib/sonarr"
  ];

  managedPaths = mediaDirs ++ stateDirs;

  directoryRules = map (dir: "d ${dir} 2775 ${shareUser} ${shareGroup} -") (mediaDirs ++ stateDirs);
in
{
  options.modules.homelab.mediaShare = {
    enable = lib.mkEnableOption "Shared system account and directory management for homelab media workloads";

    collaborators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Regular users that should be added to the shared media group.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${shareGroup} = {
      gid = shareGid;
    };

    users.users = lib.mkMerge [
      {
        ${shareUser} = {
          isSystemUser = true;
          group = shareGroup;
          home = "/var/lib/share";
          createHome = true;
          description = "Shared service account for media automation";
          uid = shareUid;
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
          ${pkgs.coreutils}/bin/chown ${shareUser}:${shareGroup} "$dir"
          ${pkgs.coreutils}/bin/chmod 2775 "$dir"
        done
      '';
    };
  };
}
