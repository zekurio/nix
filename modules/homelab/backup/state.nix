{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.backup;
    postgresql = config.services.postgresql;
    mountpoint = "/${cfg.dataset}";
    snapshotDatasets = [cfg.dataset] ++ lib.optionals cfg.offsite.enable cfg.offsite.datasets;

    # Postgres stops last, after its dumps, so it is not in stopUnits.
    downUnits = cfg.stopUnits ++ lib.optional postgresql.enable "postgresql.service";

    knownUnits = lib.concatMap (type: map (name: "${name}.${type}") (lib.attrNames config.systemd."${type}s")) [
      "service"
      "timer"
      "target"
    ];

    # Anchored at /, the root of the transfer.
    excludes =
      [
        "/nix/"
        "/tmp/"
        "/var/tmp/"
        "/var/cache/"
        "/home/*/.cache/"
        "/root/.cache/"
        "/lost+found/"
        "/var/lib/systemd/coredump/"
        # Podman pulls the images again on first start.
        "/var/lib/containers/storage/"
      ]
      ++ map (swap: swap.device) config.swapDevices
      ++ lib.optional (config.nix.settings ? build-dir) "${config.nix.settings.build-dir}/";

    window = pkgs.writeShellApplication {
      name = "backup-state";
      runtimeInputs = [
        config.boot.zfs.package
        config.systemd.package
        pkgs.coreutils
        pkgs.rsync
        pkgs.util-linux
        postgresql.package
      ];
      text = ''
        dest=${lib.escapeShellArg mountpoint}
        dumps=${lib.escapeShellArg cfg.dumpDir}

        # Without the dataset mounted, rsync would fill the SSD itself.
        if [ "$(findmnt --noheadings --output SOURCE --mountpoint "$dest")" != ${lib.escapeShellArg cfg.dataset} ]; then
          echo "${cfg.dataset} is not mounted at $dest" >&2
          exit 1
        fi

        # Stopping a unit also stops whatever Requires, BindsTo or is PartOf
        # it. Record every active unit the window takes down so ExecStopPost
        # starts them again, even when this script fails halfway.
        declare -A seen=()
        queue=(${lib.escapeShellArgs downUnits})
        while [ "''${#queue[@]}" -gt 0 ]; do
          unit=''${queue[0]}
          queue=("''${queue[@]:1}")
          if [ -n "''${seen[$unit]:-}" ]; then
            continue
          fi
          seen[$unit]=1
          for dependent in $(systemctl show --property=RequiredBy,BoundBy,ConsistsOf --value -- "$unit"); do
            queue+=("$dependent")
          done
        done
        for unit in "''${!seen[@]}"; do
          if systemctl --quiet is-active -- "$unit"; then
            printf '%s\n' "$unit"
          fi
        done > "$RUNTIME_DIRECTORY/units"

        ${lib.optionalString (cfg.stopUnits != []) ''
          systemctl stop -- ${lib.escapeShellArgs cfg.stopUnits}
        ''}

        ${lib.optionalString postgresql.enable ''
          export PGPORT=${toString postgresql.settings.port}
          # Logical dumps restore on any later major version; the copied data
          # directory only on the same one. The redirects run as root, so
          # postgres needs no access to the dump directory.
          rm -rf "$dumps.new"
          install -d -m 0700 "$dumps.new"
          runuser -u postgres -- pg_dumpall --globals-only > "$dumps.new/globals.sql"
          databases=$(runuser -u postgres -- psql --no-psqlrc --tuples-only --no-align \
            --command "SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate")
          while IFS= read -r database; do
            if [ -n "$database" ]; then
              runuser -u postgres -- pg_dump --format=custom --compress=0 -- "$database" > "$dumps.new/$database.dump"
            fi
          done <<< "$databases"
          rm -rf "$dumps"
          mv "$dumps.new" "$dumps"

          # A stopped cluster copies as a consistent data directory.
          systemctl stop postgresql.service
        ''}

        # --inplace with deltas rewrites only the changed blocks, so the
        # snapshots of the copy hold just the night's changes.
        status=0
        rsync --archive --hard-links --acls --xattrs --one-file-system --numeric-ids \
          --delete --delete-excluded --inplace --no-whole-file \
          --exclude-from=${pkgs.writeText "backup-state-exclude" (lib.concatLines excludes)} \
          / "$dest/" || status=$?
        # 24: files vanished during the copy, as logs and sockets do.
        if [ "$status" -ne 0 ] && [ "$status" -ne 24 ]; then
          exit "$status"
        fi

        # One atomic snapshot, so the files on tank match the database state
        # in the copy. It replaces the previous one only after a full copy.
        snapshots=(${lib.escapeShellArgs (map (dataset: "${dataset}@${cfg.snapshot}") snapshotDatasets)})
        for snapshot in "''${snapshots[@]}"; do
          if zfs list -H -o name "$snapshot" >/dev/null 2>&1; then
            zfs destroy "$snapshot"
          fi
        done
        zfs snapshot "''${snapshots[@]}"
      '';
    };

    restart = pkgs.writeShellApplication {
      name = "backup-state-restart";
      runtimeInputs = [config.systemd.package];
      text = ''
        units="$RUNTIME_DIRECTORY/units"
        if [ -s "$units" ]; then
          mapfile -t active < "$units"
          systemctl start -- "''${active[@]}"
        fi
      '';
    };
  in {
    options.services.homelab.backup = {
      enable = lib.mkEnableOption "a nightly copy of the system SSD to tank";

      dataset = lib.mkOption {
        type = lib.types.str;
        default = "tank/backups/${config.networking.hostName}";
        description = "ZFS dataset holding the copy of the system SSD. It must be mounted at /<dataset>.";
      };

      startAt = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 04:30:00";
        description = "When the backup window opens, as a systemd calendar expression.";
      };

      stopUnits = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          Units stopped during the backup window, so the state they keep on
          the SSD is copied while nothing writes to it. Service modules add
          their own. Units whose state rebuilds itself (Caddy's certificates,
          Samba's passwords from sops) or that must keep running (Tailscale,
          fan control) stay up. The window waits for listed oneshots that are
          already running.
        '';
      };

      dumpDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/backup/postgresql";
        readOnly = true;
        description = "Where the window writes its PostgreSQL dumps. The copy on tank carries them.";
      };

      snapshot = lib.mkOption {
        type = lib.types.str;
        default = "backup";
        readOnly = true;
        description = "Name of the snapshot the window takes of the copy and every offsite dataset.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions =
        map (unit: {
          assertion = lib.elem unit knownUnits;
          message = "services.homelab.backup.stopUnits: ${unit} is not a defined service, timer or target.";
        })
        cfg.stopUnits;

      systemd.services.backup-state = {
        description = "Copy the system SSD to tank";
        inherit (cfg) startAt;
        # Ordering after a oneshot that is already running makes the window
        # wait for it; ordering after a running daemon changes nothing.
        after = cfg.stopUnits ++ ["nixos-upgrade.service"];
        restartIfChanged = false;
        onFailure = config.modules.notify.onFailure;
        serviceConfig = {
          Type = "oneshot";
          RuntimeDirectory = "backup-state";
          ExecStart = lib.getExe window;
          ExecStopPost = lib.getExe restart;
          # Bring the services back even if the copy hangs.
          TimeoutStartSec = "1h";
          # The restart waits for Fluxer's health checks.
          TimeoutStopSec = "15min";
        };
      };
    };
  };
}
