{
  config,
  lib,
  ...
}: let
  cfg = config.services.homelab.fluxer;
  # Each sops key is the variable's name in lowercase. fluxer-nix generates
  # the others into /var/lib/fluxer-secrets: the setup token, the ActivityPub
  # signing key, and the NATS and Valkey passwords.
  names = [
    "FLUXER_ADMIN_OAUTH_CLIENT_SECRET"
    "FLUXER_ADMIN_SECRET_KEY_BASE"
    "FLUXER_CONNECTION_INITIATION_SECRET"
    "FLUXER_EMAIL_SMTP_PASSWORD"
    "FLUXER_ERLANG_COOKIE"
    "FLUXER_GATEWAY_RPC_AUTH_TOKEN"
    "FLUXER_KLIPY_API_KEY"
    "FLUXER_LIVEKIT_API_SECRET"
    "FLUXER_MEDIA_PROXY_SECRET_KEY"
    "FLUXER_MEDIA_PROXY_UPLOAD_RELAY_SECRET_BASE64"
    "FLUXER_PROFILE_PSEUDONYM_SECRET"
    "FLUXER_S3_SECRET_ACCESS_KEY"
    "FLUXER_SEARCH_API_KEY"
    "FLUXER_SUDO_MODE_SECRET"
    "FLUXER_VAPID_PRIVATE_KEY"
    "FLUXER_VAPID_PUBLIC_KEY"
    "FLUXER_YOUTUBE_API_KEY"
  ];
in {
  config = lib.mkIf cfg.enable {
    # The units read these through LoadCredential, so they stay root-only.
    services.fluxer.secrets = lib.genAttrs names (name: config.sops.secrets.${lib.toLower name}.path);
    sops.secrets = lib.genAttrs (map lib.toLower names) (_: {
      restartUnits = ["fluxer.target"];
    });
  };
}
