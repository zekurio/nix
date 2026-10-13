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
      inputs.blitzcrank.nixosModules.blitzcrank
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
        {
          assertion = config.services.homelab.blitzcrank-mcp.enable;
          message = "services.homelab.blitzcrank requires services.homelab.blitzcrank-mcp; the agent reaches every service through it.";
        }
      ];

      services.blitzcrank = {
        enable = true;
        inherit package port;
        model = "anthropic/claude-opus-5-5:medium";
        language = "German";
        webProvider = "firecrawl";
        mcpUrl = config.services.homelab.blitzcrank-mcp.url;
        environmentFile = config.sops.templates."blitzcrank.env".path;
        # Model requests authenticate to vrouter with VROUTER_API_KEY from the
        # env template. A login stored in pi's writable state outranks that key
        # and vrouter rejects it, so clear any that remains with
        # `blitzcrank auth logout <provider>`.

        # Non-secret configuration; every API key lives in the env template.
        # The Arr, SABnzbd, and Jellyfin settings belong to the MCP server.
        settings = {
          BLITZCRANK_MODELS_PATH = "${modelsFile}";
          SEERR_URL = config.services.homelab.seerr.baseUrl;
          # The Seerr account blitzcrank comments as: the id attributes its
          # comments, the name makes the server drop its own webhooks.
          SEERR_BOT_USER_ID = "2";
          SEERR_BOT_USERNAME = "blitzcrank";
        };
      };

      systemd.services.blitzcrank = {
        after = ["seerr.service" "vrouter.service"];
        wants = ["seerr.service" "vrouter.service"];
      };

      sops.templates."blitzcrank.env" = {
        content = ''
          SEERR_API_KEY=${config.sops.placeholder.seerr_api_key}
          BLITZCRANK_MCP_TOKEN=${config.sops.placeholder.blitzcrank_mcp_token}
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
        # The host comments on issues itself; the agent's Seerr reads go
        # through the MCP server.
        seerr_api_key = {};
        # Must match the token the MCP server checks on every request.
        blitzcrank_mcp_token = {};
        blitzcrank_webhook_secret = {};
        firecrawl_api_key = {};
        # A separate vrouter client key attributes requests to blitzcrank.
        vrouter_blitzcrank_api_key = {};
      };
    };
  };
}
