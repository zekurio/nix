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
      virtualisation.oci-containers.containers.fluxer-admin = {
        image = "ghcr.io/fluxerapp/fluxer-admin:${cfg.imageTag}";
        environment = {
          FLUXER_ADMIN_BASE_PATH = "/admin";
          FLUXER_ADMIN_ENDPOINT = "https://${domain}/admin";
          FLUXER_ADMIN_HOST = "0.0.0.0";
          FLUXER_ADMIN_OAUTH_REDIRECT_URI = "https://${domain}/admin/oauth2_callback";
          FLUXER_ADMIN_PORT = "8080";
          FLUXER_API_ENDPOINT = "http://api:8080";
          FLUXER_APP_ENDPOINT = "https://${domain}";
          FLUXER_STATIC_CDN_ENDPOINT = "https://${domain}";
        };
        dependsOn = [
          "fluxer-api"
        ];
        podman.sdnotify = "healthy";
        extraOptions = [
          "--memory=268435456"
          "--health-interval=10s"
          "--health-timeout=5s"
          "--health-retries=30"
          "--health-start-period=1m0s"
          "--health-on-failure=kill"
          ("--health-cmd="
            + builtins.toJSON [
              "bash"
              "-c"
              "exec 3<>/dev/tcp/127.0.0.1/8080 && printf 'GET /_health HTTP/1.0\\r\\n\\r\\n' >&3 && head -n 1 <&3 | grep -q ' 200 '"
            ])
        ];
      };
    };
  };
}
