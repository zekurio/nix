{
  flake.modules.nixos.adam = {
    config,
    lib,
    pkgs,
    ...
  }: let
    mediaShare = config.services.homelab.mediaShare;
    zfs = "${pkgs.zfs}/bin/zfs";
    ensureDataset = name: quota: ''
      if ! ${zfs} list -H -o name ${name} >/dev/null 2>&1; then
        ${zfs} create -p ${name}
      fi
      ${zfs} set quota=${quota} ${name}
    '';
    ensureUserShareDatasets = lib.concatStringsSep "\n" (lib.mapAttrsToList (_: share: let
        legacyLibraryPath = "${share.path}/Immich External Library";
      in ''
        ${ensureDataset share.dataset share.quota}
        ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg share.path}

        ${lib.optionalString (share.libraryPath != legacyLibraryPath) ''
          # Retire the compatibility mount without touching Fotos.
          if ${pkgs.util-linux}/bin/mountpoint -q ${lib.escapeShellArg legacyLibraryPath}; then
            ${pkgs.util-linux}/bin/umount ${lib.escapeShellArg legacyLibraryPath}
          fi
          if [ -d ${lib.escapeShellArg legacyLibraryPath} ]; then
            # Refuse to delete files left in an unmounted legacy directory.
            ${pkgs.coreutils}/bin/rmdir ${lib.escapeShellArg legacyLibraryPath}
          fi
        ''}
        ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg share.libraryPath}

        # The dataset root mounts as root:root 0755, shadowing the tmpfiles rule
        # (which races the mount). Own it here, after the mount already exists.
        ${pkgs.coreutils}/bin/chown ${share.owner}:${share.group} ${lib.escapeShellArg share.path}
        ${pkgs.coreutils}/bin/chmod 0700 ${lib.escapeShellArg share.path}
        ${pkgs.coreutils}/bin/chown ${share.owner}:${share.group} ${lib.escapeShellArg share.libraryPath}
        ${pkgs.coreutils}/bin/chmod 0700 ${lib.escapeShellArg share.libraryPath}
      '')
      mediaShare.userShares);
  in {
    boot = {
      supportedFilesystems = ["zfs"];
      zfs = {
        extraPools = ["tank"];
        forceImportRoot = false;
      };
    };

    networking.hostId = "eab7e93e";

    environment.systemPackages = [pkgs.zfs];

    # Automatic ZFS snapshots. Retention is deliberately asymmetric: irreplaceable
    # data (photos, per-user shares) keeps a month of dailies, while the media
    # library only keeps enough to undo an accidental mass deletion — its
    # snapshots pin deleted/upgraded release files, so deep retention would
    # bloat the pool with churn from the arr pipeline.
    services.sanoid = {
      enable = true;
      templates = {
        precious = {
          hourly = 24;
          daily = 30;
          monthly = 6;
          autosnap = true;
          autoprune = true;
        };
        replaceable = {
          hourly = 24;
          daily = 7;
          autosnap = true;
          autoprune = true;
        };
      };
      datasets = {
        "tank/immich".useTemplate = ["precious"];
        "tank/fluxer" = lib.mkIf config.services.homelab.fluxer.enable {
          useTemplate = ["precious"];
        };
        "tank/shares" = {
          useTemplate = ["precious"];
          # Cover current and future per-user share datasets.
          recursive = true;
        };
        "tank/media".useTemplate = ["replaceable"];
        "tank/alloy" = {
          daily = 7;
          autosnap = true;
          autoprune = true;
        };
      };
    };

    systemd.services.tank-datasets = {
      description = "Ensure tank ZFS datasets and quotas";
      wantedBy = ["multi-user.target"];
      before = [
        "mediaShare-user-library-acl.service"
      ];
      after = ["zfs-import.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${ensureDataset "tank/media" "6000G"}
        ${ensureDataset "tank/immich" "50G"}
        ${lib.optionalString config.services.homelab.fluxer.enable ''
          ${ensureDataset "tank/fluxer" "800G"}
          # Keep attachment storage on tank; /var/lib/fluxer stays on the SSD
          # for search indexes, queues, and cache state.
          if [ "$(${zfs} get -H -o value mountpoint tank/fluxer)" != /tank/fluxer ]; then
            ${zfs} set mountpoint=/tank/fluxer tank/fluxer
          fi
          if [ "$(${zfs} get -H -o value mounted tank/fluxer)" != yes ]; then
            ${zfs} mount tank/fluxer
          fi
          # Fluxer's SeaweedFS container bind-mounts this directory (see the
          # storage module). Rootful podman runs the
          # container as root, so root:root 0700 is sufficient.
          ${pkgs.coreutils}/bin/mkdir -p /tank/fluxer/seaweedfs
          ${pkgs.coreutils}/bin/chown root:root /tank/fluxer/seaweedfs
          ${pkgs.coreutils}/bin/chmod 0700 /tank/fluxer/seaweedfs
        ''}
        ${ensureDataset "tank/alloy" "100G"}
        ${ensureDataset "tank/shares" "50G"}
        ${ensureUserShareDatasets}
      '';
    };

    systemd.services.fluxer-storage = lib.mkIf config.services.homelab.fluxer.enable {
      requires = ["tank-datasets.service"];
      after = ["tank-datasets.service"];
    };

    # Dataset reconciliation reapplies the private 0700 modes, which collapses
    # the named Immich ACL mask. Re-run the ACL service after every dataset-unit
    # restart, including those caused by nixos-rebuild.
    systemd.services.mediaShare-user-library-acl.partOf = ["tank-datasets.service"];
    systemd.services.mediaShare-user-library-acl.requires = ["tank-datasets.service"];
    systemd.services.mediaShare-user-library-acl.after = ["tank-datasets.service"];

    # Immich must only scan after the library permissions have been restored.
    systemd.services.immich-server.partOf = ["tank-datasets.service"];
    systemd.services.immich-server.requires = ["mediaShare-user-library-acl.service"];
    systemd.services.immich-server.after = ["mediaShare-user-library-acl.service"];
    systemd.services.samba-smbd.requires = ["tank-datasets.service"];
    systemd.services.samba-smbd.after = ["tank-datasets.service"];
  };
}
