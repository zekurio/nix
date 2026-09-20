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
      virtualisation.oci-containers.containers.fluxer-media-proxy = {
        image = "ghcr.io/fluxerapp/fluxer-media-proxy:${cfg.imageTag}";
        environment = {
          FLUXER_MEDIA_PROXY_HOST = "0.0.0.0";
          FLUXER_MEDIA_PROXY_MODE = "upload";
          FLUXER_MEDIA_PROXY_PORT = "8080";
          FLUXER_MEDIA_PROXY_PUBLIC_ENDPOINT = "https://${domain}/media";
          FLUXER_MEDIA_PROXY_STORAGE_BACKEND = "s3";
          FLUXER_S3_READ_SIGNED = "true";
        };
        dependsOn = [
          "fluxer-nats"
        ];
        extraOptions = [
          "--memory=536870912"
          "--dns=1.1.1.1"
          "--dns=1.0.0.1"
        ];
      };
      systemd.services.podman-fluxer-media-proxy = {
        requires = ["fluxer-seaweedfs-init.service"];
        after = ["fluxer-seaweedfs-init.service"];
      };
    };
  };
}
