{
  # The CachyOS kernel builds sched_ext but runs EEVDF until a userspace
  # scheduler is loaded. lavd is tuned for latency-sensitive interactive
  # workloads such as games on a single-CCD part.
  services.scx-loader = {
    enable = true;
    config = {
      default_sched = "scx_lavd";
      default_mode = "Auto";
      # Follow power-profiles-daemon: gamemode switches the profile to
      # performance for a game's lifetime and back to balanced afterwards,
      # so the scheduler's power mode tracks it without switching loader
      # modes. Setting the flags replaces lavd's built-in Auto flags.
      scheds.scx_lavd.auto_mode = ["--autopower"];
    };
  };
}
