{
  config,
  lib,
  ...
}: let
  cfg = config.services.homelab.fluxer;
  # fluxer-nix runs SeaweedFS as a dynamic user, so its state directory is
  # the private one.
  stateDir = "/var/lib/private/fluxer-seaweedfs";
in {
  config = lib.mkIf cfg.enable {
    # Attachments stay on tank, under its quota, snapshots and offsite
    # backup. systemd hands the bind mount to the dynamic user on start.
    # nofail keeps a missing tank from holding up boot.
    fileSystems.${stateDir} = {
      device = "/tank/fluxer/seaweedfs";
      fsType = "none";
      options = [
        "bind"
        "nofail"
        "x-systemd.requires=zfs-mount.service"
        "x-systemd.after=zfs-mount.service"
      ];
    };
    systemd.services.fluxer-seaweedfs.unitConfig.RequiresMountsFor = [stateDir];
  };
}
