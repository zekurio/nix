{
  config,
  lib,
  pkgs,
  ...
}: let
  mediaShare = config.modules.homelab.mediaShare;
  zfs = "${pkgs.zfs}/bin/zfs";
  ensureDataset = name: quota: ''
    if ! ${zfs} list -H -o name ${name} >/dev/null 2>&1; then
      ${zfs} create -p ${name}
    fi
    ${zfs} set quota=${quota} ${name}
  '';
  ensureUserShareDatasets = lib.concatStringsSep "\n" (lib.mapAttrsToList (_: share: ''
      ${ensureDataset share.dataset share.quota}
      # The dataset root mounts as root:root 0755, shadowing the tmpfiles rule
      # (which races the mount). Own it here, after the mount already exists.
      ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg share.path} ${lib.escapeShellArg share.libraryPath}
      ${pkgs.coreutils}/bin/chown ${share.owner}:${share.group} ${lib.escapeShellArg share.path}
      ${pkgs.coreutils}/bin/chmod 0700 ${lib.escapeShellArg share.path}
      ${pkgs.coreutils}/bin/chown ${share.owner}:${share.group} ${lib.escapeShellArg share.libraryPath}
      ${pkgs.coreutils}/bin/chmod 0700 ${lib.escapeShellArg share.libraryPath}
    '')
    mediaShare.userShares);
in {
  systemd.services.tank-datasets = {
    description = "Ensure tank ZFS datasets and quotas";
    wantedBy = ["multi-user.target"];
    before = ["mediaShare-user-library-acl.service"];
    after = ["zfs-import.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${ensureDataset "tank/media" "5700G"}
      ${ensureDataset "tank/immich" "1000G"}
      ${ensureDataset "tank/alloy" "100G"}
      ${ensureDataset "tank/shares" "none"}
      ${ensureUserShareDatasets}
    '';
  };
}
