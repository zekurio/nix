{
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.services.homelab.orianna;
  domain = "ori.${config.services.homelab.domains.zekurio}";
  # Orianna's default, 8080, is taken on adam.
  port = 8070;
in {
  imports = [
    inputs.orianna.nixosModules.orianna
  ];

  options.services.homelab.orianna = {
    enable = lib.mkEnableOption "Orianna, a bot with proposals, polls, role menus and karma for Fluxer";
    instance = lib.mkOption {
      type = lib.types.str;
      default = "https://chat.${config.services.homelab.domains.zekurio}";
      description = "Fluxer instance origin; the bot reads /.well-known/fluxer from it.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.orianna = {
      enable = true;
      tokenFile = config.sops.secrets.orianna_bot_token.path;
      clientSecretFile = config.sops.secrets.orianna_client_secret.path;
      # Only deployment keys from Orianna's src/config.ts belong here; unknown
      # keys stop the bot at startup. Each guild's settings live in the bot's
      # database and are edited with !settings or on the web interface.
      settings = {
        inherit (cfg) instance;
        web = {
          # The bot's application needs <publicUrl>/auth/callback as a
          # redirect URI.
          publicUrl = "https://${domain}";
          # Not a secret: the browser sees it in every sign-in redirect.
          clientId = "1564755150420049920";
          host = "127.0.0.1";
          inherit port;
        };
      };
    };

    services.homelab.backup.stopUnits = ["orianna.service"];

    # The unit reads both through LoadCredential, so they stay root-only.
    sops.secrets = {
      orianna_bot_token.restartUnits = ["orianna.service"];
      orianna_client_secret.restartUnits = ["orianna.service"];
    };

    # Public: members sign in with their Fluxer account, and the calls behind
    # every page need that session.
    services.homelab.caddy.virtualHosts.orianna = {
      inherit domain;
      public = true;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
