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
  ensurePersonalShareDatasets = lib.optionalString (mediaShare.personalShares.users != {}) ''
    ${ensureDataset mediaShare.personalShares.dataset mediaShare.personalShares.rootQuota}
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: share: ensureDataset "${mediaShare.personalShares.dataset}/${name}" share.quota
      )
      mediaShare.personalShares.users
    )}
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
      ${ensurePersonalShareDatasets}
    '';
  };
}
