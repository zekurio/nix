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
  ensureVaultDataset = lib.optionalString mediaShare.vault.enable ''
    ${ensureDataset mediaShare.vault.dataset mediaShare.vault.quota}
    # The dataset root mounts as root:root 0755, shadowing the tmpfiles rule
    # (which races the mount). Own it here, after the mount already exists.
    ${pkgs.coreutils}/bin/chown ${mediaShare.vault.owner}:share ${mediaShare.vault.path}
    ${pkgs.coreutils}/bin/chmod 0700 ${mediaShare.vault.path}
  '';
in {
  systemd.services.tank-datasets = {
    description = "Ensure tank ZFS datasets and quotas";
    wantedBy = ["multi-user.target"];
    after = ["zfs-import.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${ensureDataset "tank/media" "5700G"}
      ${ensureDataset "tank/share" "500G"}
      ${ensureDataset "tank/immich" "1000G"}
      ${ensureDataset "tank/alloy" "100G"}
      ${ensureVaultDataset}
    '';
  };
}
