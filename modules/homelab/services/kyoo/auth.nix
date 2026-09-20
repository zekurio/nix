{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: {
    config = lib.mkIf config.services.homelab.kyoo.enable {
      sops.secrets.kyoo_api_key = {};
      sops.secrets.kyoo_oidc_env = {
        restartUnits = ["podman-kyoo-auth.service"];
      };
      sops.templates."kyoo-auth.env" = {
        content = ''
          KEIBI_APIKEY_SCANNER=${config.sops.placeholder.kyoo_api_key}
        '';
        restartUnits = ["podman-kyoo-auth.service"];
      };

      virtualisation.oci-containers.containers.kyoo-auth = {
        environmentFiles = [
          config.sops.templates."kyoo-auth.env".path
          config.sops.secrets.kyoo_oidc_env.path
        ];
        environment = {
          OIDC_POCKETID_NAME = "Pocket ID";
          OIDC_POCKETID_CLIENTID = "8f189f35-6037-428b-9204-eee4d597f9f9";
          OIDC_POCKETID_AUTHORIZATION = "https://auth.${config.services.homelab.domains.zekurio}/authorize";
          OIDC_POCKETID_TOKEN = "https://auth.${config.services.homelab.domains.zekurio}/api/oidc/token";
          OIDC_POCKETID_PROFILE = "https://auth.${config.services.homelab.domains.zekurio}/api/oidc/userinfo";
          OIDC_POCKETID_SCOPE = "openid profile email";
          OIDC_POCKETID_AUTHMETHOD = "ClientSecretBasic";
          EXTRA_OIDC_REDIRECT_URLS = "kyoo";
          KEIBI_APIKEY_SCANNER_CLAIMS = builtins.toJSON {permissions = ["core.read" "core.write"];};
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
          GUEST_CLAIMS = "";
          PROTECTED_CLAIMS = "permissions,verified";
        };
        volumes = ["/var/lib/kyoo/profile-pictures:/profile_pictures"];
      };
      # The auth image runs as distroless nonroot, UID 65532.
      systemd.tmpfiles.rules = [
        "d /var/lib/kyoo 0750 root root -"
        "d /var/lib/kyoo/profile-pictures 0700 65532 65532 -"
      ];
      systemd.services.podman-kyoo-auth.unitConfig.RequiresMountsFor = ["/var/lib/kyoo"];
    };
  };
}
