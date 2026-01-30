{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.homelab.mediaShare;

  shareUser = "share";
  shareGroup = "share";
  shareUid = 995;
  shareGid = 995;

  mediaDirs = [
    "/tank/jellyfin/sonarr"
    "/tank/jellyfin/sonarr-anime"
    "/tank/jellyfin/radarr"
    "/tank/jellyfin/radarr-anime"
    "/mnt/downloads"
    "/mnt/downloads/complete"
    "/mnt/downloads/complete/radarr-anime"
    "/mnt/downloads/complete/radarr"
    "/mnt/downloads/complete/sonarr-anime"
    "/mnt/downloads/complete/sonarr"
    "/mnt/downloads/converted"
    "/mnt/downloads/converted/radarr-anime"
    "/mnt/downloads/converted/radarr"
    "/mnt/downloads/converted/sonarr-anime"
    "/mnt/downloads/converted/sonarr"
    "/mnt/downloads/incomplete"
  ];

  directoryRules = map (dir: "d ${dir} 2775 ${shareUser} ${shareGroup} -") mediaDirs;
in {
  options.modules.homelab.mediaShare = {
    enable = lib.mkEnableOption "Shared system account and directory management for homelab media workloads";

    collaborators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["zekurio"];
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
      (lib.genAttrs [
          "jellyfin"
          "nzbget"
          "radarr"
          "sonarr"
        ] (_: {
          extraGroups = lib.mkAfter [shareGroup];
        }))
      (lib.genAttrs cfg.collaborators (_: {
        extraGroups = lib.mkAfter [shareGroup];
      }))
    ];

    systemd.tmpfiles.rules = directoryRules;
  };
}
