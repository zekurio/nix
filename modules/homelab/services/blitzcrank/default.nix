{
  flake.modules.nixos.homelab = {
    config,
    inputs,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.blitzcrank;
    dataDir = "/var/lib/blitzcrank";
    package = inputs.blitzcrank.packages.${pkgs.stdenv.hostPlatform.system}.default;
    anvilPackage = inputs.anvil.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
        anvil = {
          command = "${anvilPackage}/bin/anvilctl";
          controlSocket = config.services.anvil.daemon.controlSocket;
        };
        piModels = {
          default = "openai-codex/gpt-5.6-sol:medium";
          seerr = "openai-codex/gpt-5.6-sol:high";
          discord_triage = "openai-codex/gpt-5.6-luna:low";
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
            base_url = config.services.homelab.seerr.baseUrl;
            webhook_path = "/webhooks/seerr";
            bot_user_id = "2";
            bot_display_name = "blitzcrank";
            revisits_enabled = true;
          };

          web = {
            listen_addr = "127.0.0.1:8080";
          };

          jellyfin = {
            base_url = config.services.homelab.jellyfin.baseUrl;
            public_url = config.services.homelab.jellyfin.publicUrl;
          };
          sonarr = {
            base_url = config.services.homelab.sonarr.baseUrl;
          };
          radarr = {
            base_url = config.services.homelab.radarr.baseUrl;
          };
          sabnzbd = {
            base_url = config.services.homelab.sabnzbd.baseUrl;
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
  };
}
