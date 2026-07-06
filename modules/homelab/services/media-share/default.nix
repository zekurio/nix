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
  shareDirMode = "2775";
  shareFileMode = "0664";
  fileShareDir = "/tank/share";
  usenetDownloadsDir = cfg.downloadsRoot;
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
  ];
  sharedDirs = mediaDirs;

  # Create root dirs as setgid + group-writable
  directoryRules = map (dir: "d ${dir} ${shareDirMode} ${shareUser} ${shareGroup} -") sharedDirs;
  vaultDirectoryRule = lib.optional cfg.vault.enable "d ${cfg.vault.path} 0700 ${cfg.vault.owner} ${shareGroup} -";
  vaultSambaSettings = lib.optionalAttrs cfg.vault.enable {
    ${cfg.vault.name} = {
      path = cfg.vault.path;
      "valid users" = cfg.vault.owner;
      "force user" = cfg.vault.owner;
      "create mask" = "0600";
      "directory mask" = "0700";
      "read only" = "no";
      "browseable" = "yes";
      "guest ok" = "no";
    };
  };

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
    activeDownloadPrune=(
      -path ${lib.escapeShellArg "${usenetDownloadsDir}/incomplete/*"}
      -o
      -name '_UNPACK_*'
    )

    for d in "''${dirs[@]}"; do
      [ -d "$d" ] || continue

      # Keep managed roots owned by the shared service account without stealing
      # ownership from active downloader/importer work files.
      chown ${lib.escapeShellArg shareUser}:${lib.escapeShellArg shareGroup} "$d" || true
      chmod ${shareDirMode} "$d" || true

      # Directories must be group-writable for arr import moves/renames
      find "$d" \( "''${activeDownloadPrune[@]}" \) -prune -o -type d -exec chmod ${shareDirMode} {} + || true

      # Files should be readable and writable by the shared group, but not executable.
      find "$d" \( "''${activeDownloadPrune[@]}" \) -prune -o -type f -exec chmod ${shareFileMode} {} + || true

      # Ensure share group has rwx and inheritance works regardless of creator umask/mode
      find "$d" \( "''${activeDownloadPrune[@]}" \) -prune -o -exec setfacl -m g:${lib.escapeShellArg shareGroup}:rwX -m m::rwX {} + || true
      find "$d" \( "''${activeDownloadPrune[@]}" \) -prune -o -type d -exec setfacl -d -m g:${lib.escapeShellArg shareGroup}:rwx -m m::rwx {} + || true
    done
  '';

  sambaPasswdScript = pkgs.writeShellScript "media-share-samba-passwd" ''
    set -euo pipefail
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (user: file: ''
        pw="$(cat ${lib.escapeShellArg file})"
        if pdbedit --user=${lib.escapeShellArg user} >/dev/null 2>&1; then
          printf '%s\n%s\n' "$pw" "$pw" | smbpasswd -s ${lib.escapeShellArg user}
        else
          printf '%s\n%s\n' "$pw" "$pw" | smbpasswd -s -a ${lib.escapeShellArg user}
        fi
      '')
      cfg.samba.passwordFiles
    )}
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

    downloadsRoot = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/downloads";
      description = "Root directory (dedicated disk) for the shared download and import tree used by the usenet, torrent, and soulseek automation.";
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

    samba.passwordFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = lib.literalExpression "{ zekurio = config.sops.secrets.smb_password_zekurio.path; }";
      description = ''
        Samba account passwords keyed by username. Each value is the path to a
        file containing the plaintext SMB password (typically a SOPS secret). A
        oneshot service creates or updates the matching tdbsam account before
        smbd starts; each referenced UNIX user must already exist.
      '';
    };

    nfs.enable = lib.mkEnableOption "NFSv4 exports for homelab files and media";

    vault = {
      enable = lib.mkEnableOption "a private, network-discoverable SMB share for a single user";

      name = lib.mkOption {
        type = lib.types.str;
        default = "vault";
        description = "SMB share name exposed to clients.";
      };

      owner = lib.mkOption {
        type = lib.types.str;
        description = "Existing NixOS user that owns the vault and is its sole permitted SMB user.";
      };

      dataset = lib.mkOption {
        type = lib.types.str;
        default = "tank/shares/vault";
        description = "ZFS dataset backing the vault share.";
      };

      path = lib.mkOption {
        type = lib.types.str;
        default = "/tank/shares/vault";
        description = "Filesystem path of the vault dataset mountpoint.";
      };

      quota = lib.mkOption {
        type = lib.types.str;
        default = "100G";
        description = "ZFS quota for the vault dataset.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      lib.optional cfg.vault.enable {
        assertion = lib.hasAttr cfg.vault.owner config.users.users;
        message = "modules.homelab.mediaShare.vault.owner (${cfg.vault.owner}) must be an existing NixOS user.";
      }
      ++ map (name: {
        assertion = lib.hasAttr name config.users.users;
        message = "modules.homelab.mediaShare.samba.passwordFiles.${name} requires a matching NixOS user.";
      })
      (lib.attrNames cfg.samba.passwordFiles);

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

    systemd.tmpfiles.rules = directoryRules ++ aclRules ++ vaultDirectoryRule;

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
      settings =
        {
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
          media = {
            path = "/tank/media";
            "valid users" = lib.concatStringsSep " " cfg.collaborators;
            "force group" = shareGroup;
            "create mask" = shareFileMode;
            "directory mask" = shareDirMode;
            "read only" = "no";
            "browseable" = "yes";
            "guest ok" = "no";
          };
        }
        // vaultSambaSettings;
    };

    systemd.services.samba-passwd = lib.mkIf (cfg.samba.enable && cfg.samba.passwordFiles != {}) {
      description = "Provision Samba account passwords";
      before = ["samba-smbd.service"];
      requiredBy = ["samba-smbd.service"];
      after = ["systemd-tmpfiles-setup.service"];
      unitConfig.RequiresMountsFor = "/var/lib/samba";
      path = [
        config.services.samba.package
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = sambaPasswdScript;
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
