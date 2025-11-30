{
  config,
  lib,
  pkgs,
  ...
}:
let
  b2Cfg = config.services.backups.b2;
  localCfg = config.services.backups.local;

  # Shared option definitions to reduce duplication
  mkPathsOption = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Absolute paths that should be backed up.";
  };

  mkExcludePathsOption = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Paths that will be excluded from the backup.";
  };

  mkExtraBackupArgsOption = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Additional flags passed to restic backup.";
  };

  mkPruneKeepOption = lib.mkOption {
    type = lib.types.attrsOf lib.types.int;
    default = {
      daily = 7;
      weekly = 4;
      monthly = 12;
    };
    description = "Retention policy mapped to restic --keep-* switches.";
  };

  mkTimerOption = lib.mkOption {
    type = lib.types.str;
    default = "daily";
    description = "systemd OnCalendar expression used for scheduling backups.";
  };

  mkRandomizedDelaySecOption = lib.mkOption {
    type = lib.types.str;
    default = "45m";
    description = "RandomizedDelaySec applied to the backup timer.";
  };

  mkInitializeOption = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to initialize the repository automatically if it does not exist.";
  };

  mkUserOption = lib.mkOption {
    type = lib.types.str;
    default = "root";
    description = "User that performs the backups.";
  };

  mkPasswordSecretNameOption = lib.mkOption {
    type = lib.types.str;
    default = "restic_password";
    description = "SOPS secret containing the restic repository password.";
  };

  # Helper to build restic backup configuration
  mkResticBackup =
    {
      cfg,
      passwordSecret ? null,
      environmentFile ? null,
    }:
    let
      pruneOpts = lib.mapAttrsToList (name: value: "--keep-${name} ${toString value}") cfg.pruneKeep;
      excludeArgs = map (path: "--exclude=${path}") cfg.excludePaths;
    in
    {
      inherit (cfg)
        paths
        repository
        initialize
        user
        ;
      timerConfig = {
        OnCalendar = cfg.timer;
        RandomizedDelaySec = cfg.randomizedDelaySec;
        Persistent = true;
      };
      pruneOpts = pruneOpts;
      extraBackupArgs = cfg.extraBackupArgs ++ excludeArgs;
    }
    // lib.optionalAttrs (passwordSecret != null) {
      passwordFile = config.sops.secrets.${passwordSecret}.path;
    }
    // lib.optionalAttrs (environmentFile != null) {
      inherit environmentFile;
    };
in
{
  options.services.backups = {
    # Backblaze B2 backup configuration
    b2 = {
      enable = lib.mkEnableOption "Restic backups to Backblaze B2";

      repository = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "b2:backups:adam";
        description = "Restic repository string, typically b2:<bucket>:<path>.";
      };

      paths = mkPathsOption;
      excludePaths = mkExcludePathsOption;
      extraBackupArgs = mkExtraBackupArgsOption;
      pruneKeep = mkPruneKeepOption;
      timer = mkTimerOption;
      randomizedDelaySec = mkRandomizedDelaySecOption;
      initialize = mkInitializeOption;
      user = mkUserOption;
      passwordSecretName = mkPasswordSecretNameOption;

      environmentSecretName = lib.mkOption {
        type = lib.types.str;
        default = "restic_env";
        description = "SOPS secret that provides B2 credentials as environment variables.";
      };

      unitName = lib.mkOption {
        type = lib.types.str;
        default = "backblaze-b2";
        description = "Identifier used for the restic systemd units.";
      };
    };

    # Local ZFS backup configuration
    local = {
      enable = lib.mkEnableOption "Restic backups to local ZFS dataset";

      repository = lib.mkOption {
        type = lib.types.str;
        default = "/tank/backup/restic";
        example = "/tank/backup/restic";
        description = "Local path to the restic repository (typically on a ZFS dataset).";
      };

      paths = mkPathsOption;
      excludePaths = mkExcludePathsOption;
      extraBackupArgs = mkExtraBackupArgsOption;
      pruneKeep = mkPruneKeepOption;
      timer = mkTimerOption;
      randomizedDelaySec = mkRandomizedDelaySecOption;
      initialize = mkInitializeOption;
      user = mkUserOption;

      unitName = lib.mkOption {
        type = lib.types.str;
        default = "local-zfs";
        description = "Identifier used for the restic systemd units.";
      };
    };
  };

  config = lib.mkMerge [
    # B2 backup configuration
    (lib.mkIf b2Cfg.enable (
      let
        backupName = b2Cfg.unitName;
        envSecret = b2Cfg.environmentSecretName;
        passwordSecret = b2Cfg.passwordSecretName;
      in
      {
        assertions = [
          {
            assertion = b2Cfg.repository != "";
            message = "services.backups.b2.repository must be set when the service is enabled.";
          }
          {
            assertion = b2Cfg.paths != [ ];
            message = "services.backups.b2.paths must include at least one path.";
          }
        ];

        sops.secrets.${envSecret} = {
          owner = b2Cfg.user;
          group = b2Cfg.user;
          mode = "0400";
        };

        sops.secrets.${passwordSecret} = {
          owner = b2Cfg.user;
          group = b2Cfg.user;
          mode = "0400";
        };

        services.restic.backups.${backupName} = mkResticBackup {
          cfg = b2Cfg;
          inherit passwordSecret;
          environmentFile = config.sops.secrets.${envSecret}.path;
        };
      }
    ))

    # Local ZFS backup configuration (unencrypted for easier restores)
    (lib.mkIf localCfg.enable (
      let
        backupName = localCfg.unitName;
        pruneOpts = lib.mapAttrsToList (name: value: "--keep-${name} ${toString value}") localCfg.pruneKeep;
        excludeArgs = map (path: "--exclude=${path}") localCfg.excludePaths;
        passwordFile = "/run/keys/${backupName}-password";
      in
      {
        assertions = [
          {
            assertion = localCfg.repository != "";
            message = "services.backups.local.repository must be set when the service is enabled.";
          }
          {
            assertion = localCfg.paths != [ ];
            message = "services.backups.local.paths must include at least one path.";
          }
        ];

        # Create a simple password file for local unencrypted backups
        # Restic requires a password, but for local backups we can use a simple static one
        systemd.tmpfiles.rules = [
          "f ${passwordFile} 0400 ${localCfg.user} ${localCfg.user} - local-backup"
        ];

        systemd.services."${backupName}-password" = {
          wantedBy = [ "multi-user.target" ];
          before = [ "restic-backups-${backupName}.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = pkgs.writeScript "create-password" ''
              #!${pkgs.bash}/bin/bash
              echo -n "local-unencrypted-backup" > ${passwordFile}
            '';
          };
        };

        services.restic.backups.${backupName} = {
          inherit (localCfg)
            paths
            repository
            initialize
            user
            ;
          inherit passwordFile;
          timerConfig = {
            OnCalendar = localCfg.timer;
            RandomizedDelaySec = localCfg.randomizedDelaySec;
            Persistent = true;
          };
          pruneOpts = pruneOpts;
          extraBackupArgs = localCfg.extraBackupArgs ++ excludeArgs;
        };
      }
    ))
  ];
}
