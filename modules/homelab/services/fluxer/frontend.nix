{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.fluxer;
    domain = "chat.${config.services.homelab.domains.zekurio}";
  in {
    config = lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.fluxer-app-proxy = {
        image = "ghcr.io/fluxerapp/fluxer-app-proxy-self-hosted:${cfg.imageTag}";
        environment = {
          DISCOVERY_UPSTREAM_URL = "http://edge:8088/.well-known/fluxer";
          FLUXER_APP_PROXY_HOST = "0.0.0.0";
          FLUXER_APP_PROXY_PORT = "8080";
          FLUXER_BASE_DOMAIN = "${domain}";
          FLUXER_CSP_EXTRA_CONNECT_SRC = "";
          FLUXER_CSP_EXTRA_DEFAULT_SRC = "";
          FLUXER_CSP_EXTRA_FONT_SRC = "";
          FLUXER_CSP_EXTRA_FRAME_SRC = "";
          FLUXER_CSP_EXTRA_IMG_SRC = "";
          FLUXER_CSP_EXTRA_MANIFEST_SRC = "";
          FLUXER_CSP_EXTRA_MEDIA_SRC = "";
          FLUXER_CSP_EXTRA_SCRIPT_SRC = "";
          FLUXER_CSP_EXTRA_STYLE_SRC = "";
          FLUXER_CSP_EXTRA_WORKER_SRC = "";
          FLUXER_CSP_REPORT_URI = "";
          FLUXER_PUBLIC_ORIGIN = "";
          FLUXER_PUBLIC_PORT = "443";
          FLUXER_PUBLIC_SCHEME = "https";
          PUBLIC_BOOTSTRAP_API_ENDPOINT = "/api";
          PUBLIC_BOOTSTRAP_API_PUBLIC_ENDPOINT = "https://${domain}/api";
        };
        dependsOn = [
          "fluxer-api"
          "fluxer-edge"
        ];
        extraOptions = [
          "--memory=268435456"
        ];
      };
      virtualisation.oci-containers.containers.fluxer-static-proxy = {
        image = "ghcr.io/fluxerapp/fluxer-static:${cfg.imageTag}";
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
              "http://127.0.0.1:8080/avatars/0.png"
            ])
        ];
      };
    };
  };
}
