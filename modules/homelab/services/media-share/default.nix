{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.modules.homelab.mediaShare;

    shareUser = cfg.user;
    shareGroup = cfg.group;
    shareUid = 950;
    shareGid = 950;
    shareDirMode = "2775";
    shareFileMode = "0664";
    usenetDownloadsDir = cfg.downloadsRoot;
    torrentDownloadsDir = cfg.torrentDownloadsRoot;
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
      cfg.musicDir
      "/tank/media/shows"
      "/tank/media/anime"
      "/tank/media/movies"
      "/tank/media/porn"
      usenetDownloadsDir
      "${usenetDownloadsDir}/complete"
      "${usenetDownloadsDir}/complete/manual"
      "${usenetDownloadsDir}/complete/radarr"
      "${usenetDownloadsDir}/complete/sonarr"
      "${usenetDownloadsDir}/complete/slskd"
      "${usenetDownloadsDir}/incomplete"
      "${usenetDownloadsDir}/incomplete/slskd"
      torrentDownloadsDir
      "${torrentDownloadsDir}/complete"
      "${torrentDownloadsDir}/incomplete"
    ];
    sharedDirs = mediaDirs;

    # Create root dirs as setgid + group-writable
    directoryRules = map (dir: "d ${dir} ${shareDirMode} ${shareUser} ${shareGroup} -") sharedDirs;
    userShareDirectoryRules = lib.mapAttrsToList (_: share: "d ${builtins.toJSON share.path} 0700 ${share.owner} ${share.group} -") cfg.userShares;
    userLibraryDirectoryRules =
      lib.mapAttrsToList (
        _: share: "d ${builtins.toJSON share.libraryPath} 0700 ${share.owner} ${share.group} -"
      )
      cfg.userShares;
    userShareSambaSettings = lib.listToAttrs (
      lib.mapAttrsToList (_: share: {
        name = share.name;
        value = {
          path = share.path;
          "valid users" = share.owner;
          "force user" = share.owner;
          "create mask" = "0600";
          "directory mask" = "0700";
          "read only" = "no";
          "browseable" = "yes";
          "guest ok" = "no";
        };
      })
      cfg.userShares
    );
    userSharePaths = lib.mapAttrsToList (_: share: share.path) cfg.userShares;
    immichLibraryPaths = lib.mapAttrsToList (_: share: share.libraryPath) cfg.userShares;

    userShareAclScript = pkgs.writeShellScript "media-share-user-library-acl" ''
      set -euo pipefail

      sharePaths=(${lib.concatStringsSep " " (map lib.escapeShellArg userSharePaths)})
      libraryPaths=(${lib.concatStringsSep " " (map lib.escapeShellArg immichLibraryPaths)})

      for share in "''${sharePaths[@]}"; do
        [ -d "$share" ] || continue
        # Each share is private to its owner over SMB; Immich may only traverse it.
        setfacl -m u:immich:--x,m::--x "$share"
      done

      for library in "''${libraryPaths[@]}"; do
        [ -d "$library" ] || continue

        # Keep each per-user share private while allowing Immich to read only the
        # explicitly named external-library subtree.
        find "$library" -type d -exec setfacl \
          -m u::rwx,g::---,o::---,m::r-x,u:immich:r-x \
          -m d:u::rwx,d:g::---,d:o::---,d:m::r-x,d:u:immich:r-x {} +
        find "$library" -type f -exec setfacl \
          -m u::rw-,g::---,o::---,m::r--,u:immich:r-- {} +
      done
    '';

    userShareOptions = {name, ...}: {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "SMB share name for this user's private share.";
        };

        owner = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Unix user that owns and authenticates to this private share.";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = shareGroup;
          description = "Group assigned to the private share root.";
        };

        dataset = lib.mkOption {
          type = lib.types.str;
          default = "tank/shares/${name}";
          description = "ZFS dataset backing this user's private share.";
        };

        path = lib.mkOption {
          type = lib.types.str;
          default = "/tank/shares/${name}";
          description = "Filesystem path of this user's private share.";
        };

        quota = lib.mkOption {
          type = lib.types.str;
          default = "100G";
          description = "ZFS quota for this user's private share.";
        };

        libraryPath = lib.mkOption {
          type = lib.types.str;
          default = "/tank/shares/${name}/Immich External Library";
          description = "Immich external-library subtree inside this user's private share.";
        };
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
        -path ${lib.escapeShellArg "${torrentDownloadsDir}/incomplete/*"}
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

      user = lib.mkOption {
        type = lib.types.str;
        default = "share";
        description = "Shared service account owning the media tree.";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "share";
        description = "Shared group granting media services write access to the media tree.";
      };

      umask = lib.mkOption {
        type = lib.types.str;
        default = "0002";
        description = "UMask for services writing into the shared media tree (keeps files group-writable).";
      };

      musicDir = lib.mkOption {
        type = lib.types.str;
        default = "/tank/media/music";
        description = "Shared music library directory.";
      };

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
        description = "Root directory (dedicated disk) for the shared download and import tree used by the usenet and soulseek automation.";
      };

      torrentDownloadsRoot = lib.mkOption {
        type = lib.types.str;
        default = "/tank/media/downloads/torrents";
        description = "Torrent download tree inside the media ZFS dataset so imports can use hardlinks.";
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

      userShares = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule userShareOptions);
        default = {};
        description = "Private per-user SMB shares and their Immich library subtrees.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions =
        (lib.mapAttrsToList (name: share: {
            assertion = lib.hasAttr share.owner config.users.users;
            message = "modules.homelab.mediaShare.userShares.${name}.owner (${share.owner}) must be an existing NixOS user.";
          })
          cfg.userShares)
        ++ (lib.mapAttrsToList (name: share: {
            assertion = lib.hasAttr share.owner cfg.samba.passwordFiles;
            message = "modules.homelab.mediaShare.userShares.${name} requires a Samba password file for ${share.owner}.";
          })
          cfg.userShares)
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
        (lib.genAttrs ["jellyfin" "navidrome" "qbittorrent" "radarr" "sabnzbd" "slskd" "sonarr"] (_: {
          extraGroups = lib.mkAfter [shareGroup];
        }))
        (lib.genAttrs cfg.collaborators (_: {
          extraGroups = lib.mkAfter [shareGroup];
        }))
      ];

      systemd.tmpfiles.rules = directoryRules ++ aclRules ++ userShareDirectoryRules ++ userLibraryDirectoryRules;

      systemd.services.mediaShare-user-library-acl = lib.mkIf (cfg.userShares != {}) {
        description = "Grant Immich read access to per-user external-library trees";
        wantedBy = ["multi-user.target"];
        before = ["immich-server.service"];
        after = [
          "local-fs.target"
          "systemd-tmpfiles-setup.service"
        ];
        unitConfig.RequiresMountsFor = lib.concatStringsSep " " userSharePaths;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = userShareAclScript;
        };
        path = [
          pkgs.acl
          pkgs.findutils
        ];
      };

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
          // userShareSambaSettings;
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
          /tank/media ${tailnetCidr}(${nfsShareOptions})
        '';
      };
    };
  };
}
