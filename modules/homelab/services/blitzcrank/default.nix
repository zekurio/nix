{
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.services.homelab.blitzcrank;
in {
  imports = [
    inputs.blitzcrank.nixosModules.default
  ];

  options.services.homelab.blitzcrank = {
    enable = lib.mkEnableOption "Blitzcrank Jellyseerr/Jellyfin Discord support agent";
  };

  config = lib.mkIf cfg.enable {
    services.blitzcrank = {
      enable = true;
      environmentFile = config.sops.secrets.blitzcrank_env.path;
      publicName = "blitzcrank";
      timezone = config.time.timeZone;
      automations.enable = true;
      runtime = {
        default = {
          provider = "codex-oauth";
          model = "gpt-5.5";
          reasoningEffort = "low";
        };
        discordTriage = {
          model = "gpt-5.4-mini";
          reasoningEffort = "none";
        };
      };
    };

    systemd.services.blitzcrank = {
      environment = {
        DISCORD_TRIAGE_THRESHOLD = "0.75";
        DISCORD_THREAD_ARCHIVE_MINUTES = "1440";
        DISCORD_CONTEXT_RECENT_MESSAGES = "12";
        SEERR_WEBHOOK_LISTEN_ADDR = "127.0.0.1:8080";
        SEERR_WEBHOOK_PATH = "/webhooks/seerr";
        EXA_BASE_URL = "https://api.exa.ai";
        OPENAI_BASE_URL = "https://api.openai.com/v1";
        CODEX_FAST_MODE = "false";
        AGENT_MAX_TOOL_ITERATIONS = "15";
        AGENT_RUN_TIMEOUT = "5m";
        OPENROUTER_X_TITLE = "blitzcrank";
      };
      serviceConfig.SupplementaryGroups = ["share"];
    };

    sops.secrets.blitzcrank_env = {
      owner = "blitzcrank";
      group = "blitzcrank";
      mode = "0400";
    };
  };
}
