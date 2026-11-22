{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.backup;
  postgresql = config.services.postgresql;
  resticUnits = ["restic-backups-offsite.service" "restic-offsite-snapshots.service"];

  # Postgres stops last, after its dumps, so it is not in stopUnits.
  downUnits = cfg.stopUnits ++ lib.optional postgresql.enable "postgresql.service";

  knownUnits = lib.concatMap (type: map (name: "${name}.${type}") (lib.attrNames config.systemd."${type}s")) [
    "service"
    "timer"
    "target"
  ];

  window = pkgs.writeShellApplication {
    name = "backup-state";
    runtimeInputs = [
      config.boot.zfs.package
      config.systemd.package
      pkgs.coreutils
      pkgs.util-linux
      postgresql.package
    ];
    text = ''
      dumps=${lib.escapeShellArg cfg.dumpDir}

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

        # Restic reads the data directory while the cluster is stopped.
        systemctl stop postgresql.service
      ''}

      # Snapshot all tank datasets together while database writers are down.
      snapshots=(${lib.escapeShellArgs (map (dataset: "${dataset}@${cfg.snapshot}") cfg.offsite.datasets)})
      for snapshot in "''${snapshots[@]}"; do
        if zfs list -H -o name "$snapshot" >/dev/null 2>&1; then
          zfs destroy "$snapshot"
        fi
      done
      zfs snapshot "''${snapshots[@]}"
      touch "$RUNTIME_DIRECTORY/ready"
      systemctl start restic-backups-offsite.service
    '';
  };

  restart = pkgs.writeShellApplication {
    name = "backup-state-restart";
    runtimeInputs = [config.systemd.package pkgs.coreutils];
    text = ''
      rm -f "$RUNTIME_DIRECTORY/ready"
      # A timed-out or cancelled systemctl start leaves its job running.
      # Stop the upload before letting services write to the SSD again.
      status=0
      systemctl stop -- ${lib.escapeShellArgs resticUnits} || status=$?
      units="$RUNTIME_DIRECTORY/units"
      if [ -s "$units" ]; then
        mapfile -t active < "$units"
        systemctl start -- "''${active[@]}" || status=$?
      fi
      exit "$status"
    '';
  };
in {
  options.services.homelab.backup = {
    enable = lib.mkEnableOption "a consistent offsite backup of the system SSD and selected ZFS datasets";

    startAt = lib.mkOption {
      type = lib.types.str;
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

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["/var/lib/example/downloads/" "/home/*/Git/**/target/"];
      description = ''
        Restic exclude patterns for the SSD and selected ZFS datasets.
        A leading slash anchors a pattern at the filesystem root.
      '';
    };

    dumpDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/backup/postgresql";
      readOnly = true;
      description = "Where the window writes its PostgreSQL dumps for Restic.";
    };

    snapshot = lib.mkOption {
      type = lib.types.str;
      default = "backup";
      readOnly = true;
      description = "Name of the snapshot the window takes of each offsite ZFS dataset.";
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
      description = "Back up the system SSD and selected ZFS datasets offsite";
      # Ordering after a oneshot that is already running makes the window
      # wait for it; ordering after a running daemon changes nothing.
      after = cfg.stopUnits ++ ["network-online.target" "nixos-upgrade.service"];
      wants = ["network-online.target"];
      restartIfChanged = false;
      onFailure = config.modules.notify.onFailure;
      serviceConfig = {
        Type = "oneshot";
        RuntimeDirectory = "backup-state";
        ExecStart = lib.getExe window;
        ExecStopPost = lib.getExe restart;
        # Leave time for the upload and bring services back if it hangs.
        TimeoutStartSec = "6h";
        # The restart waits for Fluxer's health checks.
        TimeoutStopSec = "15min";
      };
    };

    modules.healthchecks.units.backup-state = {
      schedule = cfg.startAt;
      grace = 7 * 60 * 60;
    };
  };
}
