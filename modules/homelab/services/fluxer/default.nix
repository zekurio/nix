{
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.services.homelab.fluxer;
  zekurio = config.services.homelab.domains.zekurio;
in {
  imports = [
    inputs.fluxer-nix.nixosModules.default
  ];

  options.services.homelab.fluxer = {
    enable = lib.mkEnableOption "Fluxer chat services with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    services.fluxer = {
      enable = true;
      domain = "chat.${zekurio}";
      livekit.openFirewall = true;
      settings = {
        # Only read on a fresh instance's first boot; Fluxer locks the mode
        # once anyone signs up. Username sign-in never uses tags.
        FLUXER_ACCOUNT_IDENTITY = "username";
        # One community only; discovery has nothing to list.
        FLUXER_DISCOVERY_ENABLED = false;
        # Pocket ID's issuer resolves to adam's LAN address.
        FLUXER_SSO_ALLOW_PRIVATE_ADDRESSES = true;
        # The homelab Caddy sets this header; fluxer-nix trusts it only
        # with its own edge.
        FLUXER_TRUST_CLIENT_IP_HEADER = true;
        FLUXER_CLIENT_IP_HEADER_NAME = "x-forwarded-for";
        # Email fields saved in the admin panel override these and the
        # password secret. SSO and captcha have no settings at all and live
        # only in the admin panel.
        FLUXER_EMAIL_ENABLED = true;
        FLUXER_EMAIL_PROVIDER = "smtp";
        FLUXER_EMAIL_FROM_EMAIL = "fluxer@${zekurio}";
        FLUXER_EMAIL_FROM_NAME = "Fluxer";
        FLUXER_EMAIL_SMTP_HOST = "smtp.purelymail.com";
        FLUXER_EMAIL_SMTP_PORT = 465;
        FLUXER_EMAIL_SMTP_SECURE = true;
        FLUXER_EMAIL_SMTP_USERNAME = "homelab@${zekurio}";
      };
    };

    # fluxer-nix's target holds the whole instance, NATS and Meilisearch
    # included, but not the shared PostgreSQL, which the backup stops last.
    services.homelab.backup.stopUnits = ["fluxer.target"];
  };
}
