{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.blitzcrank;
  port = 8484;
  package = inputs.blitzcrank.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
    # pi 1.1.0 lacks Jev 1.14 in its classifier catalog, and models.json only
    # adds chat models. Drop this once pi includes the versioned classifier.
    postInstall =
      (old.postInstall or "")
      + ''
        catalog="$out/lib/blitzcrank/node_modules/@earendil-works/pi-ai/dist/providers/data/openrouter.json"
        ${pkgs.jq}/bin/jq '
          .["typesafe-system-one"]["classifier:typesafe/jev-1.14"] =
            (.["typesafe-system-one"]["classifier:typesafe/jev-1.13"] + {
              id: "typesafe/jev-1.14",
              name: "TypeSafe: Jev 1.14",
              input: ["text", "image"],
              contextWindow: 262144
            })
        ' "$catalog" > "$catalog.tmp"
        mv "$catalog.tmp" "$catalog"
      '';
  });
in {
  imports = [
    inputs.blitzcrank.nixosModules.blitzcrank
  ];

  options.services.homelab.blitzcrank = {
    enable = lib.mkEnableOption "Blitzcrank homelab agent";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.homelab.blitzcrank-mcp.enable;
        message = "services.homelab.blitzcrank requires services.homelab.blitzcrank-mcp; the agent reaches every service through it.";
      }
    ];

    services.blitzcrank = {
      enable = true;
      inherit package port;
      model = "anthropic/claude-opus-5-5:xhigh";
      # Required by every gateway; it names Fluxer threads.
      helperModel = "anthropic/claude-haiku-5-5:medium";
      # Reviews every write that can remove or change media before it runs.
      gateModel = "anthropic/claude-haiku-5-5:high";
      # Replies follow the reporter's language. This is only the fallback and
      # the language of the host's own notices.
      language = "German";
      webProvider = "firecrawl";
      mcpUrl = config.services.homelab.blitzcrank-mcp.url;
      # blitzcrank_env supplies ANTHROPIC_API_KEY for the built-in provider.
      environmentFile = config.sops.templates."blitzcrank.env".path;
    };

    sops.templates."blitzcrank.env" = {
      content = ''
        ${config.sops.placeholder.blitzcrank_env}
        BLITZCRANK_MCP_TOKEN=${config.sops.placeholder.blitzcrank_mcp_token}
        FIRECRAWL_API_KEY=${config.sops.placeholder.firecrawl_api_key}
      '';
      mode = "0400";
      # Rendering a changed template does not touch the unit, so without this
      # a rotated key would sit unread until the next unrelated restart.
      restartUnits = ["blitzcrank.service"];
    };

    sops.secrets = {
      blitzcrank_env = {};
      # Must match the token the MCP server checks on every request.
      blitzcrank_mcp_token = {};
      firecrawl_api_key = {};
    };
  };
}
