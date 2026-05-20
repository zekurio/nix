{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.blitzcrank;
  dataDir = "/var/lib/blitzcrank";
  package = inputs.blitzcrank.packages.${pkgs.system}.default.overrideAttrs (_: {
    vendorHash = "sha256-sT3heEOjSXHgCKvAw+mXPkQDULJaDF4NCFQVGZFed00=";
  });
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
      package = package;
      environmentFile = config.sops.secrets.blitzcrank_env.path;
      dataDir = dataDir;
      publicName = "blitzcrank";
      openAIAuth = "codex-oauth";
      timezone = config.time.timeZone;
      automations.enable = true;

      settings = {
        discord = {
          guild_id = "418795186475237376";
          owner_id = "144853050761150465";
          channel_id = "1473398718127407188";
          triage_threshold = 0.75;
          thread_archive_minutes = 1440;
          context_recent_messages = 12;
        };

        seerr = {
          base_url = "http://127.0.0.1:5055";
          webhook_path = "/webhooks/seerr";
          bot_user_id = "23";
          bot_display_name = "blitzcrank";
        };

        web.listen_addr = "127.0.0.1:8080";

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
              provider = "openai";
              model = "gpt-5.5";
              reasoning_effort = "low";
            };
            seerr = {
              provider = "openai";
              model = "gpt-5.5";
              reasoning_effort = "medium";
            };
            discord = {
              provider = "openai";
              model = "gpt-5.5";
              reasoning_effort = "low";
            };
            automation = {
              provider = "openai";
              model = "gpt-5.5";
              reasoning_effort = "medium";
            };
            discord_triage = {
              provider = "openai";
              model = "gpt-5.4-mini";
              reasoning_effort = "none";
            };
            sandbox_review = {
              provider = "openai";
              model = "gpt-5.4-mini";
              reasoning_effort = "low";
            };
          };
        };
      };
    };

    systemd.services.blitzcrank = {
      serviceConfig.SupplementaryGroups = ["share"];
    };

    sops.secrets.blitzcrank_env = {
      owner = "blitzcrank";
      group = "blitzcrank";
      mode = "0400";
    };
  };
}
