{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.healthchecks;
  host = config.networking.hostName;
  heartbeatCheck = "${host}-heartbeat";
  heartbeatSchedule = "*:0/5";
  upgradeCheck = "${host}-upgrade";

  # `hc-ping SLUG [start|fail] < BODY`. The project's ping key and a slug
  # address a check, and `create=1` makes a missing check on its first ping.
  ping = pkgs.writeShellApplication {
    name = "hc-ping";
    runtimeInputs = [pkgs.curl];
    text = ''
      curl --fail --silent --show-error \
        --retry 3 --retry-all-errors --max-time 10 \
        --data-binary @- \
        "https://hc-ping.com/$(< ${lib.escapeShellArg cfg.pingKeyFile})/$1''${2:+/$2}?create=1" >/dev/null
    '';
  };

  # ExecStopPost learns how the run ended from SERVICE_RESULT.
  upgradeResult = pkgs.writeShellScript "nixos-upgrade-ping" ''
    if [ "$SERVICE_RESULT" = success ]; then
      exec ${lib.getExe ping} ${upgradeCheck} </dev/null
    fi
    # healthchecks.io keeps the body, so the failure's log is a click away.
    ${config.systemd.package}/bin/journalctl --output cat --lines 100 \
      _SYSTEMD_INVOCATION_ID="$INVOCATION_ID" \
      | ${lib.getExe ping} ${upgradeCheck} fail
  '';

  # A check created by its first ping expects one ping a day, whatever the
  # timer behind it. healthchecks.io parses OnCalendar itself, so each check
  # gets its timer's own schedule instead.
  checks =
    {
      ${heartbeatCheck} = {
        schedule = heartbeatSchedule;
        grace = 15 * 60;
      };
    }
    // lib.optionalAttrs config.system.autoUpgrade.enable {
      ${upgradeCheck} = {
        schedule = config.system.autoUpgrade.dates;
        # Also the longest a run may take from its start ping, so it covers
        # the timer's randomized delay and a build that misses the caches.
        grace = 3 * 60 * 60;
      };
    };

  # Matching on the slug updates the check the pings already created. "*"
  # attaches every integration, as a check created by a ping gets.
  checkFiles = lib.mapAttrsToList (slug: check:
    pkgs.writeText "healthchecks-${slug}.json" (builtins.toJSON (check
      // {
        name = slug;
        inherit slug;
        tz = config.time.timeZone;
        channels = "*";
        unique = ["slug"];
      })))
  checks;

  provision = pkgs.writeShellApplication {
    name = "hc-provision";
    runtimeInputs = [pkgs.curl];
    text = ''
      # The key reaches curl on stdin, never in its arguments.
      put() {
        printf 'header = "X-Api-Key: %s"\n' "$(< ${lib.escapeShellArg cfg.apiKeyFile})" \
          | curl --config - --fail --silent --show-error \
            --retry 3 --retry-all-errors --max-time 10 \
            --json "@$1" https://healthchecks.io/api/v3/checks/ >/dev/null
      }

      ${lib.concatMapStrings (file: "put ${file}\n") checkFiles}
    '';
  };
in {
  options.modules.healthchecks = {
    enable = lib.mkEnableOption "healthchecks.io pings for uptime and auto-upgrades";
    pingKeyFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        File holding the healthchecks.io project's ping key. Anyone with it
        can ping the project's checks and so hide an outage; keep it secret.
      '';
    };
    apiKeyFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        File holding a read-write API key for the same project, used to set
        each check's schedule. It can edit and delete every check in the
        project; keep it secret.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # healthchecks.io alerts once these pings stop. That covers the host
    # being down or offline, which nothing on the host can report.
    systemd.services.healthchecks-heartbeat = {
      description = "Ping healthchecks.io while this host is up";
      startAt = heartbeatSchedule;
      serviceConfig = {
        Type = "oneshot";
        # A missed ping is what the check is there to notice. Leaving the
        # unit failed would also raise Beszel's failed-service alert.
        ExecStart = "-${lib.getExe ping} ${heartbeatCheck}";
      };
    };

    # The check definitions are part of the unit, so a switch that changes
    # them runs it again. Unlike a ping, a failure here leaves the unit
    # failed: a wrong schedule means false alerts or missed ones.
    systemd.services.healthchecks-provision = {
      description = "Set this host's healthchecks.io check schedules";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe provision;
      };
    };

    # The start ping lets healthchecks.io also flag a run that hangs.
    systemd.services.nixos-upgrade = lib.mkIf config.system.autoUpgrade.enable {
      serviceConfig = {
        ExecStartPre = "-${lib.getExe ping} ${upgradeCheck} start";
        ExecStopPost = "-${upgradeResult}";
      };
    };
  };
}
