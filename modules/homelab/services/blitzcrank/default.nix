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
    anvilPackage = inputs.anvil.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
        # Subscription auth: credentials come from the pi auth.json seeded
        # below, not from a provider API key in the environment file.
        model = "openai-codex/gpt-5.6-sol:high";
        language = "German";
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
          ANVIL_COMMAND = "${anvilPackage}/bin/anvilctl";
          ANVIL_CONTROL_SOCKET = config.services.anvil.daemon.controlSocket;
          # Automation cron expressions are evaluated in local time.
          TZ = config.time.timeZone;
        };
      };

      # anvilctl talks to the daemon socket, which anvil owns as the share user.
      systemd.services.blitzcrank = {
        serviceConfig.SupplementaryGroups = ["share"];
        after = ["seerr.service"];
        wants = ["seerr.service"];
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
        '';
        mode = "0400";
      };

      sops.secrets = {
        seerr_api_key = {};
        sonarr_api_key = {};
        radarr_api_key = {};
        sabnzbd_api_key = {};
        jellyfin_api_key = {};
        blitzcrank_webhook_secret = {};
        firecrawl_api_key = {};
        # Bootstrap copy of the pi auth.json (OpenAI Codex OAuth). blitzcrank
        # copies it into its state directory on start and refreshes tokens
        # there, so this value is a restore seed rather than a live mirror.
        pi_auth_json = {};
      };
    };
  };
}
