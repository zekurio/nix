{
  flake.modules.nixos.lilith = {pkgs, ...}: {
    # The CachyOS kernel builds sched_ext but runs EEVDF until a userspace
    # scheduler is loaded. lavd is tuned for latency-sensitive interactive
    # workloads such as games on a single-CCD part.
    services.scx = {
      enable = true;
      scheduler = "scx_lavd";
      package = pkgs.scx.full;
      # Follow power-profiles-daemon: gamemode switches the profile to
      # performance for a game's lifetime and back to balanced afterwards,
      # so the scheduler's power mode tracks it without scx_loader.
      extraArgs = ["--autopower"];
    };
  };
}
