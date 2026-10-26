{
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.services.homelab.fluxer;
  domain = "chat.${config.services.homelab.domains.zekurio}";
in {
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/fluxer/caddy 0750 root root -"
      "d /var/lib/fluxer/caddy/data 0750 root root -"
      "d /var/lib/fluxer/caddy/config 0750 root root -"
    ];
    virtualisation.oci-containers.containers.fluxer-edge = {
      image = "docker.io/library/caddy:2.11-alpine";
      environment = {
        FLUXER_EDGE_SITE_ADDRESS = ":8080";
        FLUXER_EDGE_TRUSTED_PROXIES = "private_ranges";
      };
      dependsOn = [
        "fluxer-admin"
        "fluxer-api"
        "fluxer-gateway"
        "fluxer-media-proxy"
        "fluxer-static-proxy"
      ];
      ports = [
        "127.0.0.1:8080:8080/tcp"
      ];
      volumes = ["${inputs.fluxer-caddyfile}:/etc/caddy/Caddyfile:ro" "/var/lib/fluxer/caddy/data:/data" "/var/lib/fluxer/caddy/config:/config"];
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
            "http://127.0.0.1:2019/config/"
          ])
      ];
    };
    services.homelab.caddy.virtualHosts.fluxer = {
      inherit domain;
      reverseProxy = "127.0.0.1:8080";
    };
  };
}
