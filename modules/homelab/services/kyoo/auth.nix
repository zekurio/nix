{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.kyoo;
    pocketId = "https://auth.${config.services.homelab.domains.zekurio}";
  in {
    config = lib.mkIf cfg.enable {
      # The image runs as distroless's nonroot UID. Naming it on the host
      # lets PostgreSQL peer auth resolve it.
      users.users.kyoo = {
        isSystemUser = true;
        uid = 65532;
        group = "kyoo";
      };
      users.groups.kyoo.gid = 65532;

      systemd.tmpfiles.rules = [
        "d /var/lib/kyoo 0755 root root -"
        "d /var/lib/kyoo/profile-pictures 0750 kyoo kyoo -"
      ];

      # Pocket ID needs a client (ID and secret in kyoo_env) with the callback
      # https://<domain>/auth/oidc/logged/pocketid (upstream's OIDC.md still
      # documents an older /api path).
      virtualisation.oci-containers.containers.kyoo-auth = {
        image = "ghcr.io/zoriya/kyoo_auth:${cfg.imageTag}";
        environment = {
          PUBLIC_URL = "https://${cfg.domain}";
          # The mobile app's scheme; upstream's compose always adds it.
          EXTRA_OIDC_REDIRECT_URLS = "kyoo";
          # Blocks password sign-up only; Pocket ID logins still create users.
          DISABLE_REGISTRATION = "true";
          # The first user becomes admin. Later users can browse and play
          # once an admin verifies them. GUEST_CLAIMS stays unset, so
          # signed-out visitors get nothing on the public vhost.
          EXTRA_CLAIMS = builtins.toJSON {
            permissions = ["core.read" "core.play"];
            verified = false;
          };
          FIRST_USER_CLAIMS = builtins.toJSON {
            permissions = [
              "users.read"
              "users.write"
              "users.delete"
              "apikeys.read"
              "apikeys.write"
              "core.read"
              "core.write"
              "core.play"
              "scanner.trigger"
              "scanner.guess"
              "scanner.search"
              "scanner.add"
            ];
            verified = true;
          };
          PROTECTED_CLAIMS = "permissions,verified";
          KEIBI_APIKEY_SCANNER_CLAIMS = builtins.toJSON {
            permissions = ["core.read" "core.write"];
          };
          OIDC_POCKETID_NAME = "Pocket ID";
          OIDC_POCKETID_LOGO = "${pocketId}/api/application-images/logo";
          OIDC_POCKETID_AUTHORIZATION = "${pocketId}/authorize";
          OIDC_POCKETID_TOKEN = "${pocketId}/api/oidc/token";
          OIDC_POCKETID_PROFILE = "${pocketId}/api/oidc/userinfo";
          OIDC_POCKETID_SCOPE = "openid email profile";
          OIDC_POCKETID_AUTHMETHOD = "ClientSecretBasic";
        };
        volumes = ["/var/lib/kyoo/profile-pictures:/profile_pictures"];
      };
    };
  };
}
