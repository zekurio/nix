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
  fileShareDir = "/tank/share";
  usenetDownloadsDir = "/var/lib/downloads";
  torrentDownloadsDir = "/tank/media/torrents";
  tailnetCidr = "100.64.0.0/10";
  smbTcpPorts = [
    139
    445
  ];
  smbUdpPorts = [
    137
    138
  ];
  mdnsUdpPort = 5353;
  nfsRootOptions = "ro,fsid=0,no_subtree_check,crossmnt";
  nfsShareOptions = "rw,sync,no_subtree_check,all_squash,anonuid=${toString shareUid},anongid=${toString shareGid},insecure";

  mediaDirs = [
    "/tank/media/music"
    "/tank/media/shows"
    "/tank/media/anime"
    "/tank/media/movies"
    usenetDownloadsDir
    "${usenetDownloadsDir}/complete"
    "${usenetDownloadsDir}/complete/manual"
    "${usenetDownloadsDir}/complete/radarr"
    "${usenetDownloadsDir}/complete/radarr-anime"
    "${usenetDownloadsDir}/complete/sonarr"
    "${usenetDownloadsDir}/complete/sonarr-anime"
    "${usenetDownloadsDir}/complete/slskd"
    "${usenetDownloadsDir}/incomplete"
    "${usenetDownloadsDir}/incomplete/slskd"
    "${usenetDownloadsDir}/converted"
    "${usenetDownloadsDir}/converted/radarr"
    "${usenetDownloadsDir}/converted/radarr-anime"
    "${usenetDownloadsDir}/converted/sonarr"
    "${usenetDownloadsDir}/converted/sonarr-anime"
    torrentDownloadsDir
    "${torrentDownloadsDir}/manual"
    "${torrentDownloadsDir}/radarr"
    "${torrentDownloadsDir}/sonarr"
    "${torrentDownloadsDir}/incomplete"
  ];
  sharedDirs = mediaDirs ++ lib.optional cfg.samba.enable fileShareDir;

  # Create root dirs as setgid + group-writable
  directoryRules = map (dir: "d ${dir} 2775 ${shareUser} ${shareGroup} -") sharedDirs;

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
    sharedDirs
  );

  fixExisting = cfg.fixExistingTrees;
  normalizeTreeScript = pkgs.writeShellScript "media-share-normalize-tree" ''
    set -euo pipefail

    dirs=(${lib.concatStringsSep " " (map lib.escapeShellArg sharedDirs)})

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
      setfacl -R -d -m g:${lib.escapeShellArg shareGroup}:rwx -m m::rwx "$d" || true
    done
  '';
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

    samba.enable = lib.mkEnableOption "SMB shares for homelab files and media";

    samba.interfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Network interfaces whose firewalls should allow SMB traffic.";
    };

    samba.discovery.enable = lib.mkEnableOption "Avahi/mDNS discovery for SMB shares";

    samba.discovery.interfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Network interfaces Avahi should use for SMB service discovery. Empty means all eligible local interfaces.";
    };

    nfs.enable = lib.mkEnableOption "NFSv4 exports for homelab files and media";
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
      (lib.genAttrs ["jellyfin" "navidrome" "radarr" "sabnzbd" "slskd" "sonarr"] (_: {
        extraGroups = lib.mkAfter [shareGroup];
      }))
      (lib.genAttrs cfg.collaborators (_: {
        extraGroups = lib.mkAfter [shareGroup];
      }))
    ];

    systemd.tmpfiles.rules = directoryRules ++ aclRules;

    networking.firewall.interfaces = lib.mkMerge [
      (lib.mkIf (cfg.samba.enable && cfg.samba.interfaces != []) (
        lib.genAttrs cfg.samba.interfaces (_: {
          allowedTCPPorts = smbTcpPorts;
          allowedUDPPorts = smbUdpPorts;
        })
      ))
      (lib.mkIf (cfg.samba.enable && cfg.samba.discovery.enable && cfg.samba.discovery.interfaces != []) (
        lib.genAttrs cfg.samba.discovery.interfaces (_: {
          allowedUDPPorts = [mdnsUdpPort];
        })
      ))
    ];

    # Fix already-existing content (created by downloaders, etc.)
    systemd.services.mediaShare-fixperms = lib.mkIf fixExisting {
      description = "Normalize media share permissions and ACLs";
      wantedBy = ["multi-user.target"];
      after = ["local-fs.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = normalizeTreeScript;
      };
      path = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.acl
      ];
    };

    systemd.timers.mediaShare-fixperms = lib.mkIf fixExisting {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "15m";
        Persistent = true;
      };
    };

    services.samba = lib.mkIf cfg.samba.enable {
      enable = true;
      openFirewall = false;
      settings = {
        global = {
          "server string" = config.networking.hostName;
          "workgroup" = "WORKGROUP";
          "map to guest" = "Never";
          "server min protocol" = "SMB3_00";
          "vfs objects" = "catia fruit streams_xattr";
          "fruit:metadata" = "stream";
          "fruit:model" = "MacSamba";
          "fruit:veto_appledouble" = "no";
          "fruit:wipe_intentionally_left_blank_rfork" = "yes";
          "fruit:delete_empty_adfiles" = "yes";
        };
        files = {
          path = fileShareDir;
          "valid users" = lib.concatStringsSep " " cfg.collaborators;
          "force group" = shareGroup;
          "create mask" = "0664";
          "directory mask" = "2775";
          "read only" = "no";
          "browseable" = "yes";
          "guest ok" = "no";
        };
        media = {
          path = "/tank/media";
          "valid users" = lib.concatStringsSep " " cfg.collaborators;
          "force group" = shareGroup;
          "create mask" = "0664";
          "directory mask" = "2775";
          "read only" = "no";
          "browseable" = "yes";
          "guest ok" = "no";
        };
      };
    };

    services.avahi = lib.mkIf (cfg.samba.enable && cfg.samba.discovery.enable) {
      enable = true;
      nssmdns4 = true;
      openFirewall = cfg.samba.discovery.interfaces == [];
      allowInterfaces = lib.mkIf (cfg.samba.discovery.interfaces != []) cfg.samba.discovery.interfaces;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
      extraServiceFiles.smb = ''
        <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
          <name replace-wildcards="yes">%h</name>
          <service>
            <type>_smb._tcp</type>
            <port>445</port>
          </service>
        </service-group>
      '';
    };

    services.nfs.server = lib.mkIf cfg.nfs.enable {
      enable = true;
      exports = ''
        /tank ${tailnetCidr}(${nfsRootOptions})
        ${fileShareDir} ${tailnetCidr}(${nfsShareOptions})
        /tank/media ${tailnetCidr}(${nfsShareOptions})
      '';
    };
  };
}
