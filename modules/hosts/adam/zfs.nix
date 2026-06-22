{pkgs, ...}: let
  zfs = "${pkgs.zfs}/bin/zfs";
  ensureDataset = name: quota: ''
    if ! ${zfs} list -H -o name ${name} >/dev/null 2>&1; then
      ${zfs} create -p ${name}
    fi
    ${zfs} set quota=${quota} ${name}
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
      ${ensureDataset "tank/immich" "1000G"}
      ${ensureDataset "tank/alloy" "none"}
    '';
  };
}
