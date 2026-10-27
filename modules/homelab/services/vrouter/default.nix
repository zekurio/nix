{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.vrouter;
  domain = "vrouter.${config.services.homelab.domains.zekurio}";
  port = 8787;
in {
  imports = [
    inputs.vrouter.nixosModules.default
  ];

  options.services.homelab.vrouter = {
    enable = lib.mkEnableOption "vrouter model gateway with Pocket ID sign-in and Caddy integration";
    baseUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:${toString port}";
      description = "URL other services use to reach the vrouter API.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.homelab.pocket-id.enable;
        message = "vrouter signs in through the homelab Pocket ID service.";
      }
    ];

    services.vrouter = {
      enable = true;
      # The upstream module's default builds against this host's nixpkgs
      # instead of the flake's own package output.
      package = inputs.vrouter.packages.${pkgs.stdenv.hostPlatform.system}.default;
      inherit port;
      # Sign-in returns here, and management writes are only accepted from
      # this origin. Caddy preserves the Host header that vrouter checks.
      publicUrl = "https://${domain}";
      # Roles come from the vrouter_role custom claim in Pocket ID, admin or
      # member, and follow it at every sign-in. People without it are turned
      # away.
      oidc = {
        issuer = config.services.pocket-id.settings.APP_URL;
        name = "Pocket ID";
        # Not a secret: the browser sees it in every sign-in redirect.
        clientId = "7d74790b-7c44-40a6-b346-e398658057ae";
      };
      # Supplies VROUTER_OIDC_CLIENT_SECRET from the Pocket ID client.
      environmentFile = config.sops.secrets.vrouter_env.path;
    };

    sops.secrets.vrouter_env.restartUnits = ["vrouter.service"];

    services.homelab.backup.stopUnits = ["vrouter.service"];

    # Public: the dashboard and /api need a Pocket ID session, and /v1
    # inference needs a vrouter API key.
    services.homelab.caddy.virtualHosts.vrouter = {
      inherit domain;
      public = true;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
