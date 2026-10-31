{
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.services.homelab.orianna;
  fluxerId = lib.types.strMatching "[0-9]{17,20}";
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
    guildId = lib.mkOption {
      type = fluxerId;
      description = "Fluxer community the bot serves; it ignores every other.";
    };
    pollsChannelId = lib.mkOption {
      type = fluxerId;
      description = "Fluxer channel where emoji and sticker proposals go up for a vote.";
    };
    adminRoles = lib.mkOption {
      type = lib.types.listOf fluxerId;
      default = [];
      description = "Fluxer role IDs whose members may run every command, such as adding an emoji without a vote.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.orianna = {
      enable = true;
      tokenFile = config.sops.secrets.orianna_bot_token.path;
      # Unknown keys stop the bot at startup, so only keys from Orianna's
      # docs/configuration.md belong here.
      settings = {
        inherit (cfg) instance guildId pollsChannelId;
        # The guild owner and Administrators may run everything regardless.
        permissions.roles = lib.genAttrs cfg.adminRoles (_: ["+*"]);
        # An empty section turns a feature on with its defaults. The default
        # maxImageBytes matches Fluxer's stock 512 KiB emoji and sticker limit.
        # A proposal's default vote threshold of 1 needs a yes from every
        # member who can see the polls channel.
        emoji = {};
        sticker = {};
        polls = {};
      };
    };

    services.homelab.backup.stopUnits = ["orianna.service"];

    # The unit reads the token through LoadCredential, so it stays root-only.
    sops.secrets.orianna_bot_token.restartUnits = ["orianna.service"];
  };
}
