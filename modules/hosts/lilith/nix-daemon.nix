{
  nix = {
    # Background rebuilds and garbage collection must never steal frametime
    # from a running game; idle classes yield entirely under load.
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";
  };
}
