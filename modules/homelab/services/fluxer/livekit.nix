{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.fluxer;
  in {
    config = lib.mkIf cfg.enable {
      sops.templates."fluxer-livekit.env" = {
        content = ''
          LIVEKIT_KEYS=fluxer: ${config.sops.placeholder.fluxer_livekit_api_secret}
        '';
        restartUnits = [
          "podman-fluxer-livekit.service"
        ];
      };
      virtualisation.oci-containers.containers.fluxer-livekit = {
        image = "docker.io/livekit/livekit-server:v1.12.0";
        environment = {
          LIVEKIT_CONFIG = "port: 7880\nlog_level: info\nrtc:\n  tcp_port: 7881\n  udp_port: 7882\n  use_external_ip: true\n  node_ip: \"\"\n  stun_servers:\n    - stun.l.google.com:19302\n    - stun1.l.google.com:19302\nwebhook:\n  api_key: fluxer\n  urls:\n    - http://api:8080/webhooks/livekit\n";
        };
        environmentFiles = [config.sops.templates."fluxer-livekit.env".path];
        ports = [
          "7881:7881/tcp"
          "7882:7882/udp"
        ];
        podman.sdnotify = "healthy";
        extraOptions = [
          "--memory=536870912"
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
              "http://127.0.0.1:7880/"
            ])
        ];
      };
      networking.firewall = {
        allowedTCPPorts = [7881];
        allowedUDPPorts = [7882];
      };
    };
  };
}
