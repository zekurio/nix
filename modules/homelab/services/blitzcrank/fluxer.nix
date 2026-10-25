{
  config,
  lib,
  ...
}: let
  cfg = config.services.homelab.blitzcrank.fluxer;
  fluxerId = lib.types.strMatching "[0-9]{17,20}";
in {
  options.services.homelab.blitzcrank.fluxer = {
    enable = lib.mkEnableOption "Blitzcrank Fluxer gateway";
    instance = lib.mkOption {
      type = lib.types.str;
      default = "https://chat.${config.services.homelab.domains.zekurio}";
      description = "Fluxer instance origin; the host reads /.well-known/fluxer from it.";
    };
    channels = lib.mkOption {
      type = lib.types.nonEmptyListOf fluxerId;
      description = "Fluxer channel IDs the bot watches.";
    };
    allowedUsers = lib.mkOption {
      type = lib.types.listOf fluxerId;
      default = [];
      description = "Fluxer user IDs allowed to ask the bot for help.";
    };
    allowedRoles = lib.mkOption {
      type = lib.types.listOf fluxerId;
      default = [];
      description = "Fluxer role IDs whose members may ask the bot for help.";
    };
    triageModel = lib.mkOption {
      type = lib.types.nonEmptyStr;
      example = "openrouter/typesafe/jev-1.14";
      description = "Classifier model as provider/model; chat models are not supported.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.homelab.blitzcrank.enable;
        message = "services.homelab.blitzcrank.fluxer requires services.homelab.blitzcrank.";
      }
      {
        assertion = cfg.allowedUsers != [] || cfg.allowedRoles != [];
        message = "Blitzcrank Fluxer requires at least one allowed user or role.";
      }
    ];

    # FLUXER_BOT_TOKEN comes from blitzcrank_env with the other bot tokens.
    services.blitzcrank = {
      gateways = ["fluxer"];
      settings = {
        FLUXER_INSTANCE_URL = cfg.instance;
        FLUXER_CHANNELS = lib.concatStringsSep "," cfg.channels;
        FLUXER_ALLOWED_USERS = lib.concatStringsSep "," cfg.allowedUsers;
        FLUXER_ALLOWED_ROLES = lib.concatStringsSep "," cfg.allowedRoles;
        # Triage uses OpenRouter directly; agent requests still use vrouter.
        FLUXER_TRIAGE_MODEL = cfg.triageModel;
      };
    };
  };
}
