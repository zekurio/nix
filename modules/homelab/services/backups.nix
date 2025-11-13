{ config
, lib
, ...
}:
let
  cfg = config.services.backups.b2;
in
{
  options.services.backups.b2 = {
    enable = lib.mkEnableOption "Restic backups to Backblaze B2";

    repository = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "b2:backups:adam";
      description = "Restic repository string, typically b2:<bucket>:<path>.";
    };

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Absolute paths that should be backed up.";
    };

    excludePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Paths that will be excluded from the backup.";
    };

    extraBackupArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional flags passed to restic backup.";
    };

    pruneKeep = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      default = {
        daily = 7;
        weekly = 4;
        monthly = 12;
      };
      description = "Retention policy mapped to restic --keep-* switches.";
    };

    timer = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "systemd OnCalendar expression used for scheduling backups.";
    };

    randomizedDelaySec = lib.mkOption {
      type = lib.types.str;
      default = "45m";
      description = "RandomizedDelaySec applied to the backup timer.";
    };

    initialize = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to initialize the repository automatically if it does not exist.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "User that performs the backups.";
    };

    environmentSecretName = lib.mkOption {
      type = lib.types.str;
      default = "restic_env";
      description = "SOPS secret that provides B2 credentials as environment variables.";
    };

    passwordSecretName = lib.mkOption {
      type = lib.types.str;
      default = "restic_password";
      description = "SOPS secret containing the restic repository password.";
    };

    unitName = lib.mkOption {
      type = lib.types.str;
      default = "backblaze-b2";
      description = "Identifier used for the restic systemd units.";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      backupName = cfg.unitName;
      envSecret = cfg.environmentSecretName;
      passwordSecret = cfg.passwordSecretName;
      pruneOpts = lib.mapAttrsToList (name: value: "--keep-${name} ${toString value}") cfg.pruneKeep;
      excludeArgs = map (path: "--exclude=${path}") cfg.excludePaths;
    in
    {
      assertions = [
        {
          assertion = cfg.repository != "";
          message = "services.backups.b2.repository must be set when the service is enabled.";
        }
        {
          assertion = cfg.paths != [ ];
          message = "services.backups.b2.paths must include at least one path.";
        }
      ];

      sops.secrets.${envSecret} = {
        owner = cfg.user;
        group = cfg.user;
        mode = "0400";
      };

      sops.secrets.${passwordSecret} = {
        owner = cfg.user;
        group = cfg.user;
        mode = "0400";
      };

      services.restic.backups.${backupName} = {
        inherit (cfg) paths repository initialize user;
        passwordFile = config.sops.secrets.${passwordSecret}.path;
        environmentFile = config.sops.secrets.${envSecret}.path;
        timerConfig = {
          OnCalendar = cfg.timer;
          RandomizedDelaySec = cfg.randomizedDelaySec;
          Persistent = true;
        };
        pruneOpts = pruneOpts;
        extraBackupArgs = cfg.extraBackupArgs ++ excludeArgs;
      };
    }
  );
}
