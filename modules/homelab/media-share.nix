{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.modules.homelab.mediaShare;
  shareUser = cfg.user;
  shareGroup = cfg.group;

  tmpfilesRules =
    map
      (dir: "${dir.kind} ${dir.path} ${dir.mode} ${shareUser} ${shareGroup} -")
      cfg.tmpfilesDirectories;

  permissionProfileBlocks =
    map
      (profile: ''
        if [ -d ${profile.path} ]; then
          ${pkgs.findutils}/bin/find ${profile.path} -type d -exec ${pkgs.coreutils}/bin/chmod ${profile.dirMode} {} \;
          ${pkgs.findutils}/bin/find ${profile.path} -type f -exec ${pkgs.coreutils}/bin/chmod ${profile.fileMode} {} \;
          ${pkgs.coreutils}/bin/chown -R ${shareUser}:${shareGroup} ${profile.path}
          ${lib.optionalString profile.setAcl ''
            ${pkgs.acl}/bin/setfacl -Rm g:${shareGroup}:rwx ${profile.path}
            ${pkgs.acl}/bin/setfacl -dRm g:${shareGroup}:rwx ${profile.path}
          ''}
        fi
      '')
      cfg.permissionProfiles;

  backupPaths =
    if cfg.useBackupPaths
    then lib.attrByPath [ "services" "backups" "b2" "paths" ] [ ] config
    else [ ];

  backupStateDirs =
    builtins.filter (dir: lib.hasPrefix "/var/lib" dir) backupPaths;

  stateDirs = lib.unique (cfg.stateDirectories ++ backupStateDirs);

  stateDirBlock =
    lib.optionalString (stateDirs != [ ]) (lib.concatMapStrings
      (dir: ''
        if [ -d ${dir} ]; then
          ${pkgs.coreutils}/bin/chown -R ${shareUser}:${shareGroup} ${dir}
        fi
      '')
      stateDirs);

  fixPermissionsScript =
    lib.concatStringsSep "\n"
      (permissionProfileBlocks
        ++ lib.optional (stateDirBlock != "") stateDirBlock);
in
{
  options.modules.homelab.mediaShare = {
    enable =
      lib.mkEnableOption "Shared system account and directory management for homelab media workloads";

    user = lib.mkOption {
      type = lib.types.str;
      default = "share";
      description = "Username used by media services.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "share";
      description = "Primary group used by media services.";
    };

    uid = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Numeric UID assigned to the shared media user, if pinning is required.";
    };

    gid = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Numeric GID assigned to the shared media group, if pinning is required.";
    };

    home = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/share";
      description = "Home directory for the shared media user.";
    };

    description = lib.mkOption {
      type = lib.types.str;
      default = "Shared service account for media automation";
      description = "Human-readable description for the shared media user.";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "video" "render" ];
      description = "Additional groups assigned to the shared media user.";
    };

    collaborators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Regular users that should be added to the shared media group.";
    };

    umask = lib.mkOption {
      type = lib.types.str;
      default = "0002";
      description = "Default umask applied to media services.";
    };

    tmpfilesDirectories = lib.mkOption {
      type =
        lib.types.listOf (lib.types.submodule ({ ... }: {
          options = {
            path = lib.mkOption {
              type = lib.types.str;
              description = "Path that should be created or relabeled.";
            };
            mode = lib.mkOption {
              type = lib.types.str;
              default = "2775";
              description = "File mode assigned to the directory.";
            };
            kind = lib.mkOption {
              type = lib.types.enum [ "d" "D" "z" "Z" ];
              default = "Z";
              description = "tmpfiles directive used for the path.";
            };
          };
        }));
      default = [ ];
      description = "Directories managed through systemd-tmpfiles for the shared media user.";
    };

    permissionProfiles = lib.mkOption {
      type =
        lib.types.listOf (lib.types.submodule ({ ... }: {
          options = {
            path = lib.mkOption {
              type = lib.types.str;
              description = "Directory whose ownership and ACLs should be enforced.";
            };
            dirMode = lib.mkOption {
              type = lib.types.str;
              default = "2775";
              description = "Mode applied to directories during the fix-permissions run.";
            };
            fileMode = lib.mkOption {
              type = lib.types.str;
              default = "0664";
              description = "Mode applied to files during the fix-permissions run.";
            };
            setAcl = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether group ACLs should be enforced for the directory.";
            };
          };
        }));
      default = [ ];
      description = "Directories whose permissions should be remediated on boot.";
    };

    stateDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional state directories that should be recursively chowned for the shared user.";
    };

    useBackupPaths = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include services.backups.b2.paths entries (when available) in the permission fixup.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${shareGroup} =
      { }
      // lib.optionalAttrs (cfg.gid != null) { gid = cfg.gid; };

    users.users =
      lib.mkMerge [
        {
          ${shareUser} =
            ({
              isSystemUser = true;
              group = shareGroup;
              home = cfg.home;
              createHome = true;
              description = cfg.description;
              extraGroups = cfg.extraGroups;
            }
            // lib.optionalAttrs (cfg.uid != null) { uid = cfg.uid; });
        }
        (lib.genAttrs cfg.collaborators (_: {
          extraGroups = lib.mkAfter [ shareGroup ];
        }))
      ];

    systemd.tmpfiles.rules =
      lib.mkIf (tmpfilesRules != [ ])
        (lib.mkAfter tmpfilesRules);

    systemd.services.media-share-fix-permissions =
      lib.mkIf (fixPermissionsScript != "") {
        description = "Homelab media share permission remediation";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
        serviceConfig.Type = "oneshot";
        script = fixPermissionsScript;
      };
  };
}
