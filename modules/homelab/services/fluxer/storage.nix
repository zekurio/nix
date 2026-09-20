{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.fluxer;
  in {
    config = lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.fluxer-seaweedfs = {
        image = "docker.io/chrislusf/seaweedfs:4.34";
        environment = {
          GOMEMLIMIT = "1536MiB";
        };
        cmd = [
          "server"
          "-s3"
          "-dir=/data"
        ];
        volumes = ["/tank/fluxer/seaweedfs:/data"];
        podman.sdnotify = "healthy";
        extraOptions = [
          "--memory=2147483648"
          "--health-interval=10s"
          "--health-timeout=5s"
          "--health-retries=20"
          "--health-start-period=1m0s"
          "--health-on-failure=kill"
          ("--health-cmd="
            + builtins.toJSON [
              "wget"
              "-q"
              "-O"
              "/dev/null"
              "http://127.0.0.1:8333/healthz"
            ])
        ];
      };
    };
  };
}
