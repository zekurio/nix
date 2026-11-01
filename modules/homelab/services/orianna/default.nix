{
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.services.homelab.orianna;
in {
  imports = [
    inputs.orianna.nixosModules.orianna
  ];

  options.services.homelab.orianna = {
    enable = lib.mkEnableOption "Orianna emoji, sticker, and poll bot for Fluxer";
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
      # Only deployment keys from Orianna's src/config.ts belong here; unknown
      # keys stop the bot at startup. Each guild's settings live in the bot's
      # database and are edited with !settings or on the web interface.
      settings = {
        inherit (cfg) instance;
      };
    };

    services.homelab.backup.stopUnits = ["orianna.service"];

    # The unit reads the token through LoadCredential, so it stays root-only.
    sops.secrets.orianna_bot_token.restartUnits = ["orianna.service"];
  };
}
