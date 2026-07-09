{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.blitzcrank;
  dataDir = "/var/lib/blitzcrank";
  package = inputs.blitzcrank.packages.${pkgs.system}.default;
in {
  imports = [
    inputs.blitzcrank.nixosModules.default
  ];

  options.services.homelab.blitzcrank = {
    enable = lib.mkEnableOption "Blitzcrank media support and automation agent";
  };

  config = lib.mkIf cfg.enable {
    services.blitzcrank = {
      enable = true;
      package = package;
      environmentFile = config.sops.secrets.blitzcrank_env.path;
      dataDir = dataDir;
      piModels = {
        default = "openai-codex/gpt-5.6-terra:medium";
        seerr = "openai-codex/gpt-5.6-terra:medium";
        automation = "openai-codex/gpt-5.6-terra:medium";
        discord = "openai-codex/gpt-5.6-terra:medium";
        discord_triage = "openai-codex/gpt-5.6-luna:medium";
        review = "openai-codex/gpt-5.6-luna:medium";
      };
      settings = {
        bot = {
          public_name = "blitzcrank";
        };

        discord = {
          guild_id = "418795186475237376";
          automation_channel_id = "1473398718127407188";
          automation_thread_lock = true;
          watched_channel_ids = ["1473398718127407188"];
        };

        seerr = {
          base_url = "http://127.0.0.1:5055";
          webhook_path = "/webhooks/seerr";
          bot_user_id = "2";
          bot_display_name = "blitzcrank";
          revisits_enabled = true;
        };

        web = {
          listen_addr = "127.0.0.1:8080";
        };

        jellyfin = {
          base_url = "http://127.0.0.1:8096";
        };
        sonarr = {
          base_url = "http://127.0.0.1:8989/sonarr";
        };
        radarr = {
          base_url = "http://127.0.0.1:7878/radarr";
        };
        sabnzbd = {
          base_url = "http://127.0.0.1:6789";
        };

        runtime = {
          automations_enabled = true;
          run_timeout = "5m";
          timezone = config.time.timeZone;
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
