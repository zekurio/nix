{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.backup;
    offsite = cfg.offsite;
    snapshotOf = mountpoint: "${mountpoint}/.zfs/snapshot/${cfg.snapshot}";
    datasetMounts = map (dataset: "/${dataset}") offsite.datasets;
    within = parent: path: lib.hasPrefix "${parent}/" path;
    # Child datasets are mounts below their parent; restic walks into them.
    paths = lib.filter (mount: !lib.any (parent: within parent mount) datasetMounts) datasetMounts ++ offsite.paths;
    knownHost =
      if offsite.port == 22
      then offsite.host
      else "[${offsite.host}]:${toString offsite.port}";
    sftp = "ssh -p ${toString offsite.port} -i ${config.sops.secrets.restic_ssh_key.path} -o ServerAliveInterval=60 ${offsite.user}@${offsite.host} -s sftp";
  in {
    options.services.homelab.backup.offsite = {
      enable = lib.mkEnableOption "an offsite restic copy of selected data over SFTP";

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
          ZFS datasets to upload, read from the snapshot the backup window
          takes. Each must be mounted at /<dataset>. A parent's snapshot does
          not contain its children, so list child datasets as well.
        '';
      };

      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Paths on the system SSD to upload, read from the window's snapshot of the copy on tank.";
      };

      exclude = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "restic exclude patterns.";
      };
    };

    config = lib.mkIf (cfg.enable && offsite.enable) {
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
        inherit paths;
        inherit (offsite) exclude;
        # The backup window starts this job once its snapshots exist.
        timerConfig = null;
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
        ];
        # Reading back a random 5% each night finds damaged packs on the
        # server within weeks instead of at restore time.
        checkOpts = ["--read-data-subset=5%"];
      };

      systemd.services.backup-state = {
        onSuccess = ["restic-backups-offsite.service"];
        # Wait for the previous upload before replacing its snapshots.
        after = ["restic-backups-offsite.service"];
      };

      systemd.services.restic-backups-offsite = {
        onFailure = config.modules.notify.onFailure;
        # Inside this unit each path shows the window's snapshot instead of
        # the live data, so the repository records the real paths and a
        # restore puts files back where they belong. Snapshot names must not
        # contain colons; they separate the bind's fields.
        serviceConfig.BindReadOnlyPaths =
          map (mount: "${snapshotOf mount}:${mount}") datasetMounts
          ++ map (path: "${snapshotOf "/${cfg.dataset}"}${path}:${path}") offsite.paths;
      };
    };
  };
}
