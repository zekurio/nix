{
  flake.modules.nixos.base = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.modules.healthchecks;
    host = config.networking.hostName;
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
    };

    config = lib.mkIf cfg.enable {
      # healthchecks.io alerts once these pings stop. That covers the host
      # being down or offline, which nothing on the host can report.
      systemd.services.healthchecks-heartbeat = {
        description = "Ping healthchecks.io while this host is up";
        startAt = "*:0/5";
        serviceConfig = {
          Type = "oneshot";
          # A missed ping is what the check is there to notice. Leaving the
          # unit failed would also raise Beszel's failed-service alert.
          ExecStart = "-${lib.getExe ping} ${host}-heartbeat";
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
  };
}
