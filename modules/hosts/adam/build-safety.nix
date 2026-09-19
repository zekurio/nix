{
  flake.modules.nixos.adam = {
    nix = {
      settings = {
        max-jobs = 1;
        cores = 2;
        max-substitution-jobs = 2;
        # /tmp is tmpfs; unpacked sources and compiler output belong on disk.
        build-dir = "/var/lib/nix-build";
      };
      daemonCPUSchedPolicy = "batch";
      daemonIOSchedPriority = 7;
    };

    systemd.tmpfiles.rules = ["d /var/lib/nix-build 0700 root root - -"];

    # Keep the existing ext4 swapfile: resizing active swap would require
    # swapping its contents back into an already busy 16 GiB machine.
    swapDevices = [
      {
        device = "/var/lib/swapfile";
        size = 16 * 1024;
      }
    ];

    # One aggregate budget across daemon workers and rebuild evaluation.
    # Throttle first, then fail builds inside this cgroup rather than letting
    # them consume all RAM/swap and trigger a host-wide OOM.
    systemd.slices.nix-build.sliceConfig = {
      MemoryHigh = "3G";
      MemoryMax = "4G";
      MemorySwapMax = "4G";
      CPUQuota = "200%";
      CPUWeight = 20;
      IOWeight = 20;
    };

    systemd.services.nix-daemon.serviceConfig = {
      Slice = "nix-build.slice";
      OOMScoreAdjust = 500;
    };

    # Start this same oneshot unit for manual upgrades: systemd coalesces
    # concurrent starts, including the weekly timer, without a lock script.
    systemd.services.nixos-upgrade = {
      environment.NIX_REMOTE = "daemon";
      serviceConfig = {
        Slice = "nix-build.slice";
        OOMScoreAdjust = 500;
      };
    };

    system.autoUpgrade.allowReboot = false;
  };
}
