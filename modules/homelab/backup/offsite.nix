{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.backup;
  offsite = cfg.offsite;
  datasetMounts = map (dataset: "/${dataset}") offsite.datasets;

  # The unit mounts the window's snapshots here, under flat names so no
  # mount sits inside another read-only snapshot.
  stage = "/run/restic-offsite";
  stageOf = dataset: "${stage}/${lib.replaceStrings ["/"] ["+"] dataset}";
  staged = lib.unique offsite.datasets;
  unmountStage = pkgs.writeShellApplication {
    name = "restic-offsite-unmount";
    runtimeInputs = [pkgs.util-linux];
    text = ''
      status=0
      for dir in ${lib.escapeShellArgs (map stageOf staged)}; do
        if mountpoint -q "$dir"; then
          umount "$dir" || status=$?
        fi
      done
      exit "$status"
    '';
  };
  mountStage = pkgs.writeShellApplication {
    name = "restic-offsite-mount";
    runtimeInputs = [config.boot.zfs.package pkgs.coreutils pkgs.util-linux];
    text =
      ''
        ${lib.getExe unmountStage}
      ''
      + lib.concatMapStrings (dataset: ''
        mkdir -p ${lib.escapeShellArg (stageOf dataset)}
        mount -t zfs -o ro ${lib.escapeShellArg "${dataset}@${cfg.snapshot}"} ${lib.escapeShellArg (stageOf dataset)}
      '')
      staged;
  };
  excludes =
    [
      "/nix"
      "/tmp"
      "/var/tmp"
      "/var/cache"
      "/home/*/.cache"
      "/root/.cache"
      "/lost+found"
      "/var/lib/systemd/coredump"
      # Podman pulls the images again on first start.
      "/var/lib/containers/storage"
    ]
    ++ map (swap: swap.device) config.swapDevices
    ++ lib.optional (config.nix.settings ? build-dir) config.nix.settings.build-dir
    ++ map (lib.removeSuffix "/") cfg.exclude;
  knownHost =
    if offsite.port == 22
    then offsite.host
    else "[${offsite.host}]:${toString offsite.port}";
  sftp = "ssh -p ${toString offsite.port} -i ${config.sops.secrets.restic_ssh_key.path} -o ServerAliveInterval=60 ${offsite.user}@${offsite.host} -s sftp";
in {
  options.services.homelab.backup.offsite = {
    host = lib.mkOption {
      type = lib.types.str;
      example = "u123456-sub1.your-storagebox.de";
      description = "SFTP server holding the restic repository.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = lib.head (lib.splitString "." offsite.host);
      defaultText = lib.literalExpression ''lib.head (lib.splitString "." host)'';
      description = "SFTP login. Hetzner Storage Box logins match the first label of their hostname.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 23;
      description = "SSH port of the SFTP server.";
    };

    hostKey = lib.mkOption {
      type = lib.types.str;
      description = "The server's SSH host key, as `ssh-keyscan` prints it after the hostname.";
    };

    datasets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        ZFS datasets to upload alongside the system SSD. Each must be mounted
        at /<dataset>. List child datasets separately so Restic can cross
        their mount boundaries.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = staged != [];
        message = "services.homelab.backup.offsite.datasets must list at least one ZFS dataset.";
      }
    ];

    sops.secrets = {
      restic_password = {};
      restic_ssh_key = {};
    };

    programs.ssh.knownHosts.restic-offsite = {
      hostNames = [knownHost];
      publicKey = offsite.hostKey;
    };

    services.restic.backups.offsite = {
      repository = "sftp:${offsite.user}@${offsite.host}:restic";
      passwordFile = config.sops.secrets.restic_password.path;
      extraOptions = ["sftp.command='${sftp}'"];
      initialize = true;
      paths = ["/"] ++ datasetMounts;
      exclude = excludes;
      # Explicit targets can be separate mounts. While walking /, skip
      # other filesystems such as /boot, /run, and unlisted tank datasets.
      extraBackupArgs = ["--one-file-system"];
      # The backup window starts this job once its snapshots exist.
      timerConfig = null;
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
      ];
      # Read back a random 5% on each run to check for damaged packs.
      checkOpts = ["--read-data-subset=5%"];
    };

    # systemd sets up restic's namespace again for every command, `+` ones
    # included. Binding the .zfs/snapshot automounts failed with ELOOP for
    # the command that started as the upload exited, so this unit mounts
    # the snapshots plainly first and unmounts them once restic is done.
    systemd.services.restic-offsite-snapshots = {
      description = "Mount the backup window's snapshots for restic";
      restartIfChanged = false;
      unitConfig.AssertPathExists = "/run/backup-state/ready";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe mountStage;
        ExecStopPost = lib.getExe unmountStage;
      };
    };

    # Started only once preparation succeeds, so a failed preparation shows up
    # here as a missing upload.
    modules.healthchecks.units.restic-backups-offsite = {
      schedule = cfg.startAt;
      grace = 7 * 60 * 60;
    };

    systemd.services.restic-backups-offsite = {
      onFailure = config.modules.notify.onFailure;
      requires = ["restic-offsite-snapshots.service"];
      after = ["restic-offsite-snapshots.service"];
      unitConfig.AssertPathExists = "/run/backup-state/ready";
      serviceConfig = {
        TimeoutStartSec = "5h";
        # Keep the original dataset paths in the repository for restores.
        BindReadOnlyPaths = map (dataset: "${stageOf dataset}:/${dataset}") staged;
      };
    };
  };
}
