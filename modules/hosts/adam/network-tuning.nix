{
  # BBR paces by measured bandwidth instead of backing off at every loss,
  # which keeps Jellyfin and Immich fast for remote clients on lossy paths.
  # It needs fq for pacing. QUIC (HTTP/3) runs its own congestion control
  # in Caddy and is unaffected.
  #
  # default_qdisc applies only to interfaces brought up after it is set, so
  # a switch leaves the running ones on fq_codel until the next reboot.
  boot.kernelModules = ["tcp_bbr"];
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };
}
