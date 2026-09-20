{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.fluxer;
  in {
    config = lib.mkIf cfg.enable {
      systemd.tmpfiles.rules = ["d /var/lib/fluxer/valkey 0750 999 1000 -"];
      virtualisation.oci-containers.containers.fluxer-valkey = {
        image = "docker.io/valkey/valkey:8.1-alpine";
        cmd = [
          "valkey-server"
          "--appendonly"
          "yes"
          "--appendfsync"
          "everysec"
          "--dir"
          "/data"
          "--maxmemory"
          "192mb"
          "--maxmemory-policy"
          "noeviction"
        ];
        volumes = ["/var/lib/fluxer/valkey:/data"];
        podman.sdnotify = "healthy";
        extraOptions = [
          "--memory=268435456"
          "--health-interval=10s"
          "--health-timeout=5s"
          "--health-retries=10"
          "--health-on-failure=kill"
          ("--health-cmd="
            + builtins.toJSON [
              "valkey-cli"
              "ping"
            ])
        ];
      };
    };
  };
}
