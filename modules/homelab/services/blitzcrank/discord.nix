{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.blitzcrank.discord;
    discordId = lib.types.strMatching "[0-9]{17,20}";
  in {
    options.services.homelab.blitzcrank.discord = {
      enable = lib.mkEnableOption "Blitzcrank Discord gateway";
      channels = lib.mkOption {
        type = lib.types.nonEmptyListOf discordId;
        description = "Discord channel IDs the bot watches.";
      };
      allowedUsers = lib.mkOption {
        type = lib.types.listOf discordId;
        default = [];
        description = "Discord user IDs allowed to ask the bot for help.";
      };
      allowedRoles = lib.mkOption {
        type = lib.types.listOf discordId;
        default = [];
        description = "Discord role IDs whose members may ask the bot for help.";
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
          message = "services.homelab.blitzcrank.discord requires services.homelab.blitzcrank.";
        }
        {
          assertion = cfg.allowedUsers != [] || cfg.allowedRoles != [];
          message = "Blitzcrank Discord requires at least one allowed user or role.";
        }
      ];

      services.blitzcrank = {
        gateways = ["discord"];
        settings = {
          DISCORD_CHANNELS = lib.concatStringsSep "," cfg.channels;
          DISCORD_ALLOWED_USERS = lib.concatStringsSep "," cfg.allowedUsers;
          DISCORD_ALLOWED_ROLES = lib.concatStringsSep "," cfg.allowedRoles;
          # Triage uses OpenRouter directly; agent requests still use vrouter.
          DISCORD_TRIAGE_MODEL = cfg.triageModel;
        };
      };
    };
  };
}
