{
  config,
  inputs,
  lib,
  pkgs,
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
      package = inputs.blitzcrank.packages.${pkgs.system}.default;
      environmentFile = config.sops.secrets.blitzcrank_env.path;
      dataDir = dataDir;
      publicName = "blitzcrank";
      timezone = config.time.timeZone;
      automations.enable = true;

      settings = {
        discord = {
          guild_id = "1262432821121908899";
          owner_id = "144853050761150465";
          channel_id = "1505596083575722044";
          triage_threshold = 0.75;
          thread_archive_minutes = 1440;
          context_recent_messages = 12;
        };

        seerr = {
          base_url = "http://127.0.0.1:5055";
          webhook_listen_addr = "127.0.0.1:8080";
          webhook_path = "/webhooks/seerr";
          bot_user_id = "23";
          bot_display_name = "blitzcrank";
        };

        jellyfin.base_url = "http://127.0.0.1:8096";
        sonarr.base_url = "http://127.0.0.1:8989/sonarr";
        radarr.base_url = "http://127.0.0.1:7878/radarr";
        sabnzbd.base_url = "http://127.0.0.1:6789";

        filesystem.allowed_roots = [
          "/var/lib/downloads"
          "/tank/media"
        ];

        exa.base_url = "https://api.exa.ai";

        llm = {
          openai.base_url = "https://api.openai.com/v1";
          openrouter = {
            base_url = "https://openrouter.ai/api/v1";
            title = "blitzcrank";
          };
          codex = {
            auth_profile = "default";
            base_url = "https://chatgpt.com/backend-api/codex";
            fast = "true";
          };
        };

        runtime = {
          max_tool_iterations = 15;
          run_timeout = "5m";
          context = {
            auto_compact = true;
            reserved_tokens = 2000;
            tail_turns = 2;
            preserve_recent_tokens = 0;
          };
          profiles = {
            default = {
              provider = "codex-oauth";
              model = "gpt-5.4";
              reasoning_effort = "medium";
              context_limit = 1050000;
              input_limit = 922000;
              output_limit = 128000;
            };
            seerr = {
              provider = "codex-oauth";
              model = "gpt-5.4";
              reasoning_effort = "high";
              context_limit = 1050000;
              input_limit = 922000;
              output_limit = 128000;
            };
            discord = {
              provider = "codex-oauth";
              model = "gpt-5.4";
              reasoning_effort = "medium";
              context_limit = 1050000;
              input_limit = 922000;
              output_limit = 128000;
            };
            automation = {
              provider = "codex-oauth";
              model = "gpt-5.4";
              reasoning_effort = "high";
              context_limit = 1050000;
              input_limit = 922000;
              output_limit = 128000;
            };
            discord_triage = {
              provider = "codex-oauth";
              model = "gpt-5.4-mini";
              reasoning_effort = "none";
              context_limit = 400000;
              input_limit = 272000;
              output_limit = 128000;
            };
            sandbox_review = {
              provider = "codex-oauth";
              model = "gpt-5.4-mini";
              reasoning_effort = "low";
              context_limit = 400000;
              input_limit = 272000;
              output_limit = 128000;
            };
          };
        };
      };
    };

    systemd.services.blitzcrank = {
      serviceConfig.SupplementaryGroups = [ "share" ];
    };

    sops.secrets.blitzcrank_env = {
      owner = "blitzcrank";
      group = "blitzcrank";
      mode = "0400";
    };
  };
}
