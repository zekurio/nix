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
      sops.secrets = {
        fluxer_admin_oauth_client_secret = {};
        fluxer_admin_secret_key_base = {};
        fluxer_connection_initiation_secret = {};
        fluxer_erlang_cookie = {};
        fluxer_gateway_rpc_auth_token = {};
        fluxer_livekit_api_secret = {};
        fluxer_media_proxy_secret_key = {};
        fluxer_media_proxy_upload_relay_secret_base64 = {};
        fluxer_meili_master_key = {};
        fluxer_postgres_password = {};
        fluxer_s3_secret_key = {};
        fluxer_sudo_mode_secret = {};
        fluxer_vapid_private_key = {};
        fluxer_vapid_public_key = {};
      };
      sops.templates."fluxer-common.env" = {
        content = ''
          AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.fluxer_s3_secret_key}
          FLUXER_ADMIN_OAUTH_CLIENT_SECRET=${config.sops.placeholder.fluxer_admin_oauth_client_secret}
          FLUXER_ADMIN_SECRET_KEY_BASE=${config.sops.placeholder.fluxer_admin_secret_key_base}
          FLUXER_CONNECTION_INITIATION_SECRET=${config.sops.placeholder.fluxer_connection_initiation_secret}
          FLUXER_GATEWAY_RPC_AUTH_TOKEN=${config.sops.placeholder.fluxer_gateway_rpc_auth_token}
          FLUXER_LIVEKIT_API_SECRET=${config.sops.placeholder.fluxer_livekit_api_secret}
          FLUXER_MEDIA_PROXY_SECRET_KEY=${config.sops.placeholder.fluxer_media_proxy_secret_key}
          FLUXER_MEDIA_PROXY_UPLOAD_RELAY_SECRET_BASE64=${config.sops.placeholder.fluxer_media_proxy_upload_relay_secret_base64}
          FLUXER_POSTGRES_PASSWORD=${config.sops.placeholder.fluxer_postgres_password}
          FLUXER_S3_SECRET_ACCESS_KEY=${config.sops.placeholder.fluxer_s3_secret_key}
          FLUXER_SEARCH_API_KEY=${config.sops.placeholder.fluxer_meili_master_key}
          FLUXER_SUDO_MODE_SECRET=${config.sops.placeholder.fluxer_sudo_mode_secret}
          FLUXER_VAPID_PRIVATE_KEY=${config.sops.placeholder.fluxer_vapid_private_key}
          FLUXER_VAPID_PUBLIC_KEY=${config.sops.placeholder.fluxer_vapid_public_key}
        '';
        restartUnits = [
          "podman-fluxer-admin.service"
          "podman-fluxer-api.service"
          "podman-fluxer-gateway.service"
          "podman-fluxer-gifs.service"
          "podman-fluxer-gifs-shard.service"
          "podman-fluxer-media-proxy.service"
          "podman-fluxer-messages.service"
          "podman-fluxer-messages-shard.service"
          "podman-fluxer-snowflakes.service"
          "podman-fluxer-snowflakes-shard.service"
          "podman-fluxer-unfurl.service"
          "podman-fluxer-unfurl-shard.service"
          "podman-fluxer-users.service"
          "podman-fluxer-users-shard.service"
          "podman-fluxer-worker.service"
        ];
      };
      virtualisation.oci-containers.containers =
        lib.genAttrs [
          "fluxer-admin"
          "fluxer-api"
          "fluxer-gateway"
          "fluxer-gifs"
          "fluxer-gifs-shard"
          "fluxer-media-proxy"
          "fluxer-messages"
          "fluxer-messages-shard"
          "fluxer-snowflakes"
          "fluxer-snowflakes-shard"
          "fluxer-unfurl"
          "fluxer-unfurl-shard"
          "fluxer-users"
          "fluxer-users-shard"
          "fluxer-worker"
        ] (_: {
          environment = {
            AWS_ACCESS_KEY_ID = "fluxer";
            AWS_DEFAULT_REGION = "us-east-1";
            AWS_EC2_METADATA_DISABLED = "true";
            FLUXER_API_HEADERS_TIMEOUT_MS = "30000";
            FLUXER_API_REQUEST_TIMEOUT_MS = "120000";
            FLUXER_BASE_DOMAIN = "${domain}";
            FLUXER_CAPTCHA_ENABLED = "false";
            FLUXER_CAPTCHA_HCAPTCHA_SECRET_KEY = "";
            FLUXER_CAPTCHA_HCAPTCHA_SITE_KEY = "";
            FLUXER_CAPTCHA_PROVIDER = "none";
            FLUXER_CAPTCHA_TURNSTILE_SECRET_KEY = "";
            FLUXER_CAPTCHA_TURNSTILE_SITE_KEY = "";
            FLUXER_CLAMAV_ENABLED = "false";
            FLUXER_CLIENT_IP_HEADER_NAME = "x-forwarded-for";
            FLUXER_DATABASE_BACKEND = "postgres";
            FLUXER_DISCOVERY_ENABLED = "true";
            FLUXER_EMAIL_APP_BASE_URL = "";
            FLUXER_EMAIL_ENABLED = "false";
            FLUXER_EMAIL_FROM_EMAIL = "noreply@localhost";
            FLUXER_EMAIL_FROM_NAME = "Fluxer";
            FLUXER_EMAIL_PROVIDER = "none";
            FLUXER_EMAIL_SMTP_HOST = "";
            FLUXER_EMAIL_SMTP_PASSWORD = "";
            FLUXER_EMAIL_SMTP_PORT = "587";
            FLUXER_EMAIL_SMTP_SECURE = "true";
            FLUXER_EMAIL_SMTP_USERNAME = "";
            FLUXER_ENV = "production";
            FLUXER_INTERNAL_API_ENDPOINT = "http://api:8080";
            FLUXER_INTERNAL_GATEWAY_ENDPOINT = "http://gateway:8080";
            FLUXER_INTERNAL_MEDIA_PROXY_ENDPOINT = "http://media-proxy:8080";
            FLUXER_KLIPY_API_KEY = "";
            FLUXER_KV_URL = "redis://valkey:6379/0";
            FLUXER_LIVEKIT_API_KEY = "fluxer";
            FLUXER_LIVEKIT_DEFAULT_REGION = "{\"id\":\"default\",\"name\":\"Default\",\"emoji\":\"🌍\",\"latitude\":0,\"longitude\":0}";
            FLUXER_LIVEKIT_ENABLED = "true";
            FLUXER_LIVEKIT_INTERNAL_URL = "http://livekit:7880";
            FLUXER_LIVEKIT_URL = "https://${domain}:443/livekit";
            FLUXER_LIVEKIT_WEBHOOK_URL = "http://api:8080/webhooks/livekit";
            FLUXER_MARKETING_ENDPOINT = "https://${domain}";
            FLUXER_MEDIA_ENDPOINT = "https://${domain}/media";
            FLUXER_MEDIA_PROXY_ENDPOINT = "http://media-proxy:8080";
            FLUXER_MEDIA_PROXY_UPLOAD_RELAY_ENDPOINT = "https://${domain}/media";
            FLUXER_NATS_AUTH_TOKEN = "";
            FLUXER_NATS_JETSTREAM_URL = "nats://nats:4222";
            FLUXER_NATS_URL = "nats://nats:4222";
            FLUXER_NCMEC_ENABLED = "false";
            FLUXER_PASSKEY_ADDITIONAL_ALLOWED_ORIGINS = "https://${domain}";
            FLUXER_PASSKEY_RP_ID = "${domain}";
            FLUXER_PASSKEY_RP_NAME = "Fluxer";
            FLUXER_POSTGRES_DATABASE = "fluxer";
            FLUXER_POSTGRES_HOST = "postgres";
            FLUXER_POSTGRES_PORT = "5432";
            FLUXER_POSTGRES_PREPARED_STATEMENTS = "true";
            FLUXER_POSTGRES_SSL = "false";
            FLUXER_POSTGRES_USERNAME = "fluxer";
            FLUXER_PUBLIC_ORIGIN = "";
            FLUXER_PUBLIC_PORT = "443";
            FLUXER_PUBLIC_SCHEME = "https";
            FLUXER_S3_ACCESS_KEY_ID = "fluxer";
            FLUXER_S3_BUCKET_CDN = "fluxer";
            FLUXER_S3_BUCKET_DOWNLOADS = "fluxer-downloads";
            FLUXER_S3_BUCKET_HARVESTS = "fluxer-harvests";
            FLUXER_S3_BUCKET_REPORTS = "fluxer-reports";
            FLUXER_S3_BUCKET_UPLOADS = "fluxer-uploads";
            FLUXER_S3_ENDPOINT = "http://seaweedfs:8333";
            FLUXER_S3_FORCE_PATH_STYLE = "true";
            FLUXER_S3_PUBLIC_ENDPOINT = "http://seaweedfs:8333";
            FLUXER_S3_REGION = "us-east-1";
            FLUXER_SEARCH_ENGINE = "meilisearch";
            FLUXER_SEARCH_URL = "http://meilisearch:7700";
            FLUXER_SELF_HOSTED = "true";
            FLUXER_SMS_ENABLED = "false";
            FLUXER_SSO_ALLOW_PRIVATE_ADDRESSES = "true";
            FLUXER_STRIPE_ENABLED = "false";
            FLUXER_SVC_NATS_URL = "nats://nats:4222";
            FLUXER_SVC_SHARD_COUNT = "1";
            FLUXER_TRUST_CLIENT_IP_HEADER = "true";
            FLUXER_VAPID_EMAIL = "admin@${domain}";
            LOG_LEVEL = "info";
            NODE_ENV = "production";
          };
          environmentFiles = [config.sops.templates."fluxer-common.env".path];
        });
    };
  };
}
