{inputs, ...}: {
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.blitzcrank;
    port = 8484;
    package = inputs.blitzcrank.packages.${pkgs.stdenv.hostPlatform.system}.default;
    shareGroup = config.services.homelab.mediaShare.group;
    downloadsRoot = config.services.homelab.mediaShare.downloadsRoot;
    vrouterUrl = config.services.homelab.vrouter.baseUrl;
    # Redirects the built-in openai and anthropic providers to vrouter and keeps
    # their model catalogs. pi expands "$VROUTER_API_KEY" from the environment,
    # so the store holds the variable name and never the key. Only the OpenAI
    # base URL ends in /v1; the Anthropic client appends /v1/messages itself.
    modelsFile = pkgs.writeText "blitzcrank-models.json" (builtins.toJSON {
      providers = {
        openai = {
          baseUrl = "${vrouterUrl}/v1";
          apiKey = "$VROUTER_API_KEY";
        };
        anthropic = {
          baseUrl = vrouterUrl;
          apiKey = "$VROUTER_API_KEY";
        };
      };
    });
  in {
    imports = [
      inputs.blitzcrank.nixosModules.default
    ];

    options.services.homelab.blitzcrank = {
      enable = lib.mkEnableOption "Blitzcrank Seerr issue agent";
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.homelab.seerr.enable;
          message = "services.homelab.blitzcrank requires services.homelab.seerr; Seerr is the only mandatory backend.";
        }
        {
          assertion = config.services.homelab.vrouter.enable;
          message = "services.homelab.blitzcrank requires services.homelab.vrouter; every model request goes through it.";
        }
      ];

      services.blitzcrank = {
        enable = true;
        inherit package port;
        model = "openai/gpt-6.1-sol:high";
        language = "German";
        webProvider = "firecrawl";

        # Directories blitzcrank may inspect with ffprobe, and nothing else.
        # Include SABnzbd's completed tree and the imported libraries. Music and
        # the private tree are deliberately absent: Seerr issues never concern
        # them.
        mediaRoots = [
          downloadsRoot
          "/tank/media/shows"
          "/tank/media/anime"
          "/tank/media/movies"
        ];
        environmentFile = config.sops.templates."blitzcrank.env".path;
        # Model requests authenticate to vrouter with VROUTER_API_KEY from the
        # env template. A login stored in pi's writable state outranks that key
        # and vrouter rejects it, so clear any that remains with
        # `blitzcrank auth logout <provider>`.

        # Non-secret configuration; every API key lives in the env template.
        settings = {
          BLITZCRANK_MODELS_PATH = "${modelsFile}";
          SEERR_URL = config.services.homelab.seerr.baseUrl;
          # The Seerr account blitzcrank comments as: the id attributes its
          # comments, the name makes the server drop its own webhooks.
          SEERR_BOT_USER_ID = "2";
          SEERR_BOT_USERNAME = "blitzcrank";
          SONARR_URL = config.services.homelab.sonarr.baseUrl;
          RADARR_URL = config.services.homelab.radarr.baseUrl;
          SABNZBD_URL = config.services.homelab.sabnzbd.baseUrl;
          JELLYFIN_URL = config.services.homelab.jellyfin.baseUrl;
        };
      };

      systemd.services.blitzcrank = {
        serviceConfig.SupplementaryGroups = [shareGroup];
        after = ["seerr.service" "vrouter.service"];
        wants = ["seerr.service" "vrouter.service"];
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
          VROUTER_API_KEY=${config.sops.placeholder.vrouter_blitzcrank_api_key}
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
        # A separate vrouter client key attributes requests to blitzcrank.
        vrouter_blitzcrank_api_key = {};
      };
    };
  };
}
