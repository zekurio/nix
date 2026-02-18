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
    "/tank/media/shows"
    "/tank/media/anime"
    "/tank/media/movies"
    "/tank/media/music"
    "/mnt/downloads"
    "/mnt/downloads/converted"
    "/mnt/downloads/converted/radarr"
    "/mnt/downloads/converted/sonarr"
    "/mnt/downloads/complete"
    "/mnt/downloads/complete/radarr"
    "/mnt/downloads/complete/slskd"
    "/mnt/downloads/complete/sonarr"
    "/mnt/downloads/incomplete"
    "/mnt/downloads/incomplete/slskd"
  ];

  # Create root dirs as setgid + group-writable
  directoryRules = map (dir: "d ${dir} 2775 ${shareUser} ${shareGroup} -") mediaDirs;

  # systemd-tmpfiles supports ACL lines. These make sure the share group gets rwx,
  # and that new files/dirs inherit it (default ACL).
  #
  # Note: If your systemd is very old and doesn’t support A+/a+ here, drop these
  # and rely on the fixperms service below.
  aclRules = lib.flatten (
    map (dir: [
      # access ACL
      "a+ ${dir} - - - - g:${shareGroup}:rwx"
      # default ACL (inheritance)
      "A+ ${dir} - - - - g:${shareGroup}:rwx"
      # ensure the ACL mask doesn’t erase the added perms
      "a+ ${dir} - - - - m::rwx"
      "A+ ${dir} - - - - m::rwx"
    ])
    mediaDirs
  );

  fixExisting = cfg.fixExistingTrees;
in {
  options.modules.homelab.mediaShare = {
    enable = lib.mkEnableOption "Shared system account and directory management for homelab media workloads";

    collaborators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["zekurio"];
      description = "Regular users that should be added to the shared media group.";
    };

    fixExistingTrees = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Normalize existing permissions/ACLs under mediaDirs at boot (useful for tools that create 755/644).";
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
      (lib.genAttrs ["jellyfin" "navidrome" "nzbget" "radarr" "slskd" "sonarr"] (_: {
        extraGroups = lib.mkAfter [shareGroup];
      }))
      (lib.genAttrs cfg.collaborators (_: {
        extraGroups = lib.mkAfter [shareGroup];
      }))
    ];

    systemd.tmpfiles.rules = directoryRules ++ aclRules;

    # Fix already-existing content (created by FileFlows, downloaders, etc.)
    systemd.services.mediaShare-fixperms = lib.mkIf fixExisting {
      description = "Normalize media share permissions and ACLs";
      wantedBy = ["multi-user.target"];
      after = ["local-fs.target"];
      serviceConfig = {
        Type = "oneshot";
      };
      path = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.acl
      ];
      script = ''
        set -euo pipefail

        dirs=(${lib.concatStringsSep " " (map lib.escapeShellArg mediaDirs)})

        for d in "''${dirs[@]}"; do
          [ -d "$d" ] || continue

          # Ensure group ownership and setgid on directories
          chgrp -R ${lib.escapeShellArg shareGroup} "$d" || true
          chmod 2775 "$d" || true

          # Directories must be group-writable for arr import moves/renames
          find "$d" -type d -exec chmod 2775 {} +

          # Files commonly should be group-writable; adjust if you prefer 664/660
          find "$d" -type f -exec chmod 664 {} +

          # Ensure share group has rwx and inheritance works regardless of creator umask/mode
          setfacl -R -m g:${lib.escapeShellArg shareGroup}:rwx -m m::rwx "$d" || true
          setfacl -R -d -m g:${lib.escapeShellArg shareGroup}:rwx -m d:m::rwx "$d" || true
        done
      '';
    };
  };
}
