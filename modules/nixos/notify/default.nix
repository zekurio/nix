{
  flake.modules.nixos.base = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.modules.notify;

    send = pkgs.writeShellApplication {
      name = "ntfy-send";
      runtimeInputs = [pkgs.curl];
      text = ''
        if [ "$#" -lt 1 ]; then
          echo "usage: ntfy-send TITLE [PRIORITY] [TAGS] < MESSAGE" >&2
          exit 2
        fi

        headers=(--header "Title: $1" --header "Priority: ''${2:-default}")
        if [ -n "''${3:-}" ]; then
          headers+=(--header "Tags: $3")
        fi

        # Keep retrying for a few minutes so an alert raised during a network
        # blip still arrives.
        curl --fail --silent --show-error \
          --retry 5 --retry-all-errors --retry-delay 30 --max-time 30 \
          "''${headers[@]}" --data-binary @- \
          "$(< ${lib.escapeShellArg cfg.urlFile})" >/dev/null
      '';
    };

    # smartd pipes a mail with the full `smartctl -a` report, which overflows
    # ntfy's 4 KiB message limit. Drain it and send the summary smartd exports
    # in the environment instead.
    smartdMailer = pkgs.writeShellScript "smartd-ntfy" ''
      ${pkgs.coreutils}/bin/cat >/dev/null
      printf '%s\n' "$SMARTD_FULLMESSAGE" \
        | ${lib.getExe send} "$SMARTD_SUBJECT" urgent floppy_disk
    '';

    # ZED passes the subject as the only argument and the event report on
    # stdin. A scrub or resilver that leaves the pool healthy is routine;
    # everything else is urgent.
    zedProgram = pkgs.writeShellScript "zed-ntfy" ''
      if ${config.boot.zfs.package}/bin/zpool status -x ''${ZEVENT_POOL:+"$ZEVENT_POOL"} \
        | ${pkgs.gnugrep}/bin/grep -q healthy; then
        priority=default tags=floppy_disk
      else
        priority=urgent tags=rotating_light
      fi
      exec ${lib.getExe send} "$1" "$priority" "$tags"
    '';
  in {
    options.modules.notify = {
      enable = lib.mkEnableOption "smartd and ZED alerts pushed through ntfy";

      urlFile = lib.mkOption {
        type = lib.types.path;
        description = ''
          File holding the ntfy topic URL. Anyone who knows a topic on a
          public server can read and publish to it, so keep it secret.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      # `sudo ntfy-send TITLE < message` tests the path by hand.
      environment.systemPackages = [send];

      services.smartd.notifications.mail = {
        enable = true;
        mailer = smartdMailer;
      };

      services.zfs.zed.settings = {
        # ZED only runs its mail notifier with an address set; zed-ntfy
        # ignores it.
        ZED_EMAIL_ADDR = "ntfy";
        ZED_EMAIL_PROG = "${zedProgram}";
        ZED_EMAIL_OPTS = "'@SUBJECT@'";
        # Also report scrubs and resilvers that finish cleanly, so each
        # monthly scrub shows the alert path still works.
        ZED_NOTIFY_VERBOSE = true;
      };
    };
  };
}
