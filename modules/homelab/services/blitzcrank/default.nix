{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.services.homelab.blitzcrank;
  dataDir = "/var/lib/blitzcrank";
in
{
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
      dataDir = dataDir;
      publicName = "blitzcrank";
      timezone = config.time.timeZone;
      automations.enable = true;
      settings = {
        discord = {
          triage_threshold = 0.75;
          thread_archive_minutes = 1440;
          context_recent_messages = 12;
        };
        seerr = {
          webhook_listen_addr = "127.0.0.1:8080";
          webhook_path = "/webhooks/seerr";
        };
        exa.base_url = "https://api.exa.ai";
        llm = {
          openai.base_url = "https://api.openai.com/v1";
          openrouter.title = "blitzcrank";
          codex.service_tier = "standard";
        };
        runtime = {
          max_tool_iterations = 15;
          run_timeout = "5m";
        };
      };
      runtime = {
        default = {
          provider = "codex-oauth";
          model = "gpt-5.5";
          reasoningEffort = "medium";
        };
        seerr = {
          provider = "codex-oauth";
          model = "gpt-5.5";
          reasoningEffort = "medium";
        };
        discord = {
          provider = "codex-oauth";
          model = "gpt-5.5";
          reasoningEffort = "low";
        };
        automation = {
          provider = "codex-oauth";
          model = "gpt-5.5";
          reasoningEffort = "low";
        };
        discordTriage = {
          provider = "codex-oauth";
          model = "gpt-5.4-mini";
          reasoningEffort = "none";
        };
      };
    };

    systemd.services.blitzcrank = {
      serviceConfig.SupplementaryGroups = [ "share" ];
    };

    systemd.tmpfiles.rules = [
      "d ${dataDir} 0750 blitzcrank blitzcrank -"
      "d ${dataDir}/threads 0750 blitzcrank blitzcrank -"
    ];

    sops.secrets.blitzcrank_env = {
      owner = "blitzcrank";
      group = "blitzcrank";
      mode = "0400";
    };
  };
}
