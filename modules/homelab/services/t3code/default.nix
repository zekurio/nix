{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.t3code;
  user = "zekurio";
  home = config.users.users.${user}.home;
  inherit (config.home-manager.users.${user}.agents) t3code;
  port = 3773;
in {
  options.services.homelab.t3code.enable = lib.mkEnableOption "T3 Code remote coding server";

  config = lib.mkIf cfg.enable {
    # Agents need the user's repositories, provider credentials and Git config.
    systemd.services.t3code = {
      description = "T3 Code server";
      wantedBy = ["multi-user.target"];
      # Home Manager's activation writes the agents' settings.
      after = ["network-online.target" "home-manager-${user}.service"];
      wants = ["network-online.target" "home-manager-${user}.service"];
      path = [
        config.home-manager.users.${user}.home.path
        pkgs.bash
        pkgs.coreutils
        pkgs.nix
      ];
      environment = {
        HOME = home;
        # Gradle daemons idle for 3 hours by default and keep their Kotlin
        # daemon alive with them. Reparented to PID 1, both stay in this
        # cgroup and hold about 3G of its budget long after the build ends.
        GRADLE_OPTS = "-Dorg.gradle.daemon.idletimeout=600000";
      };
      serviceConfig = {
        ExecStart = "${lib.getExe' t3code "t3"} serve --host 127.0.0.1 --port ${toString port}";
        User = user;
        Group = config.users.users.${user}.group;
        WorkingDirectory = home;
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";
        # Everything the agents spawn lands in this cgroup, so a runaway
        # workload cannot fill RAM and swap until the host hangs. There is no
        # MemoryHigh: above it the kernel puts every task in the cgroup to
        # sleep, the server included, and its event loop stalled for minutes
        # while parallel builds sat at the limit. At MemoryMax the kernel
        # kills the largest process instead, which is the build, and
        # OOMPolicy=continue keeps the server and the other threads running.
        # oomd still kills the unit if reclaim stalls it for too long.
        MemoryMax = "8G";
        MemorySwapMax = "2G";
        OOMPolicy = "continue";
        ManagedOOMMemoryPressure = "kill";
      };
    };

    services.homelab.backup.stopUnits = ["t3code.service"];

    services.homelab.caddy.virtualHosts.t3code = {
      domain = "t3code.${config.services.homelab.domains.zekurio}";
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
