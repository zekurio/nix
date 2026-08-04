{
  flake.modules.nixos.homelab = {
    config,
    inputs,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.blitzcrank;
    port = 8484;
    package = inputs.blitzcrank.packages.${pkgs.stdenv.hostPlatform.system}.default;
    anvilctlPackage = inputs.anvil.packages.${pkgs.stdenv.hostPlatform.system}.anvilctl;
    shareGroup = config.modules.homelab.mediaShare.group;
    downloadsRoot = config.modules.homelab.mediaShare.downloadsRoot;
  in {
    imports = [
      inputs.blitzcrank.nixosModules.default
    ];

    options.services.homelab.blitzcrank = {
      enable = lib.mkEnableOption "Blitzcrank media support and automation agent";
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.homelab.seerr.enable;
          message = "services.homelab.blitzcrank requires services.homelab.seerr; Seerr is the only mandatory backend.";
        }
      ];

      services.blitzcrank = {
        enable = true;
        inherit package port;
        # Provider auth comes from the pi auth.json seeded below, not from an
        # API key in the environment file.
        model = "openrouter/deepseek/deepseek-v4-flash";
        language = "German";

        # Directories blitzcrank may inspect with ffprobe, and nothing else.
        # The three pipeline stages a language question needs, in order:
        # SABnzbd's completed tree, Anvil's converted output beside it (both
        # under downloadsRoot), and the imported library. Music and the private
        # tree are deliberately absent: Seerr issues never concern them.
        mediaRoots = [
          downloadsRoot
          "/tank/media/shows"
          "/tank/media/anime"
          "/tank/media/movies"
        ];
        environmentFile = config.sops.templates."blitzcrank.env".path;
        authSeedFile = config.sops.secrets.pi_auth_json.path;

        # Non-secret configuration; every API key lives in the env template.
        settings = {
          SEERR_URL = config.services.homelab.seerr.baseUrl;
          # The Seerr account blitzcrank comments as: the id attributes its
          # comments, the name makes the server drop its own webhooks.
          SEERR_BOT_USER_ID = "2";
          SEERR_BOT_USERNAME = "blitzcrank";
          SONARR_URL = config.services.homelab.sonarr.baseUrl;
          RADARR_URL = config.services.homelab.radarr.baseUrl;
          SABNZBD_URL = config.services.homelab.sabnzbd.baseUrl;
          JELLYFIN_URL = config.services.homelab.jellyfin.baseUrl;
          ANVIL_COMMAND = "${anvilctlPackage}/bin/anvilctl";
          ANVIL_CONTROL_SOCKET = config.services.anvil.daemon.controlSocket;
          # Automation report threads + /automation trigger. Snowflakes are
          # not secrets; the bot token lives in the env template.
          DISCORD_GUILD_ID = "418795186475237376";
          DISCORD_WATCH_CHANNEL_ID = "1473398718127407188";
          # Automation cron expressions are evaluated in local time.
          TZ = config.time.timeZone;
        };
      };

      # anvilctl talks to the daemon socket, which anvil owns as the share
      # user; the same membership makes the media tree readable for ffprobe.
      systemd.services.blitzcrank = {
        serviceConfig.SupplementaryGroups = [shareGroup];
        after = ["seerr.service" "anvil.service"];
        wants = ["seerr.service" "anvil.service"];
      };

      sops.templates."blitzcrank.env" = {
        content = ''
          SEERR_API_KEY=${config.sops.placeholder.seerr_api_key}
          SONARR_API_KEY=${config.sops.placeholder.sonarr_api_key}
          RADARR_API_KEY=${config.sops.placeholder.radarr_api_key}
          SABNZBD_API_KEY=${config.sops.placeholder.sabnzbd_api_key}
          JELLYFIN_API_KEY=${config.sops.placeholder.jellyfin_api_key}
          BLITZCRANK_WEBHOOK_SECRET=${config.sops.placeholder.blitzcrank_webhook_secret}
          FIRECRAWL_API_KEY=${config.sops.placeholder.firecrawl_api_key}
          DISCORD_BOT_TOKEN=${config.sops.placeholder.discord_bot_token}
        '';
        mode = "0400";
        # Rendering a changed template does not touch the unit, so without this
        # a rotated key would sit unread until the next unrelated restart.
        restartUnits = ["blitzcrank.service"];
      };

      sops.secrets = {
        seerr_api_key = {};
        sonarr_api_key = {};
        radarr_api_key = {};
        sabnzbd_api_key = {};
        jellyfin_api_key = {};
        blitzcrank_webhook_secret = {};
        firecrawl_api_key = {};
        discord_bot_token = {};
        # Bootstrap copy of the pi auth.json (OpenAI Codex OAuth). blitzcrank
        # copies it into its state directory on start and refreshes tokens
        # there, so this value is a restore seed rather than a live mirror.
        pi_auth_json.restartUnits = ["blitzcrank.service"];
      };
    };
  };
}
