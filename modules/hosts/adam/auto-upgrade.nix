{
  config,
  lib,
  pkgs,
  ...
}: {
  system.autoUpgrade = {
    enable = true;
    flake = "github:zekurio/nix/main#adam";
    dates = config.services.homelab.backup.startAt;
    persistent = false;
    allowReboot = false;
  };

  # Only the timer chains upgrades to backups. Manual runs can still start
  # either service individually.
  systemd.timers.nixos-upgrade.timerConfig.Unit = "weekly-maintenance.service";
  systemd.services.weekly-maintenance = {
    description = "Back up adam before the weekly upgrade";
    requires = ["backup-state.service"];
    after = ["backup-state.service"];
    onSuccess = ["nixos-upgrade.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/true";
    };
  };

  # The weekly check includes the backup and the upgrade itself.
  modules.healthchecks.units.nixos-upgrade.grace = lib.mkForce (10 * 60 * 60);
}
