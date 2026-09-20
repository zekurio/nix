{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.fluxer;
  in {
    config = lib.mkIf cfg.enable {
      systemd.tmpfiles.rules = ["d /var/lib/fluxer/nats 0750 root root -"];
      virtualisation.oci-containers.containers.fluxer-nats = {
        image = "docker.io/library/nats:2.14-alpine";
        cmd = [
          "-js"
          "-sd"
          "/data"
          "-m"
          "8222"
        ];
        volumes = ["/var/lib/fluxer/nats:/data"];
        podman.sdnotify = "healthy";
        extraOptions = [
          "--memory=268435456"
          "--health-interval=10s"
          "--health-timeout=5s"
          "--health-retries=10"
          "--health-on-failure=kill"
          ("--health-cmd="
            + builtins.toJSON [
              "wget"
              "-q"
              "-O"
              "/dev/null"
              "http://127.0.0.1:8222/healthz"
            ])
        ];
      };
    };
  };
}
