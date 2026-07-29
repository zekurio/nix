{
  flake.modules.homeManager.zekurio = {
    config,
    lib,
    pkgs,
    ...
  }: let
    firecrawlSearch = pkgs.callPackage ./_firecrawl-search.nix {};
    npmExtension = pkgs.callPackage ./_npm-extension.nix {};
    anthropicAuth = npmExtension {
      pname = "pi-anthropic-auth";
      npmName = "@gotgenes/pi-anthropic-auth";
      version = "2.0.1";
      hash = "sha512-zxRjTL5QMDj3VlfJ0vAKATh0ArqeAAOHyQRJW8K+ol73/8773Q/JthYu6BGtPRM5KNg/OnR1dXsSKTgaZBLhoQ==";
    };
    direnv = npmExtension {
      pname = "pi-direnv";
      version = "0.1.0";
      hash = "sha512-N+njfllbcKvd5qbtSMS1nP5QTSaqVZSmo8gQk8TCgWefPQidcg+FG6cY79HIJggS9RiI4FjhGyhVX8DY9kcuIA==";
    };
    jsonFormat = pkgs.formats.json {};
    piSettings = jsonFormat.generate "pi-settings.json" {
      theme = "catppuccin-frappe";
      defaultProvider = "openai-codex";
      defaultModel = "gpt-5.6-sol";
      defaultThinkingLevel = "high";
      hideThinkingBlock = true;
      steeringMode = "all";
      enabledModels = [
        "anthropic/claude-fable-5"
        "anthropic/claude-opus-5"
        "anthropic/claude-sonnet-5"
        "openai-codex/gpt-5.6-sol"
        "opencode-go/kimi-k3"
      ];

      # Nix provides every extension below, so Pi never needs npm or Bun to
      # materialize packages at runtime.
      packages = [];
    };
    effortState = jsonFormat.generate "pi-effort.json" {
      models = {
        "anthropic/claude-fable-5" = "xhigh";
        "anthropic/claude-opus-5" = "xhigh";
        "anthropic/claude-sonnet-5" = "high";
        "openai-codex/gpt-5.6-sol" = "high";
        "opencode-go/glm-5.2" = "high";
        "opencode-go/kimi-k3" = "max";
      };
    };
    priorityRoutingState = jsonFormat.generate "pi-priority-routing.json" {
      models = {
        "openai-codex/gpt-5.6-luna" = true;
        "openai-codex/gpt-5.6-sol" = true;
      };
    };
    agentDirectory = "${config.home.homeDirectory}/.pi/agent";
    mergeMutableJson = target: static: operation: ''
      mkdir -p ${lib.escapeShellArg agentDirectory}
      if [ -f ${lib.escapeShellArg target} ] && ${lib.getExe pkgs.jq} -e 'type == "object"' ${lib.escapeShellArg target} >/dev/null 2>&1; then
        dynamic=${lib.escapeShellArg target}
      else
        dynamic=${pkgs.writeText "empty-pi-state.json" "{}"}
      fi
      ${lib.getExe pkgs.jq} -s ${lib.escapeShellArg operation} "$dynamic" ${lib.escapeShellArg static} > ${lib.escapeShellArg "${target}.tmp"}
      chmod 600 ${lib.escapeShellArg "${target}.tmp"}
      mv ${lib.escapeShellArg "${target}.tmp"} ${lib.escapeShellArg target}
      unset dynamic
    '';
  in {
    home.file = {
      ".pi/agent/extensions/async-agents.ts".source = ./extensions/async-agents.ts;
      ".pi/agent/extensions/effort.ts".source = ./extensions/effort.ts;
      ".pi/agent/extensions/image-anchors.ts".source = ./extensions/image-anchors.ts;
      ".pi/agent/extensions/priority-routing.ts".source = ./extensions/priority-routing.ts;
      ".pi/agent/extensions/firecrawl-search".source = firecrawlSearch;
      ".pi/agent/extensions/pi-anthropic-auth".source = anthropicAuth;
      ".pi/agent/extensions/pi-direnv".source = direnv;
      ".pi/agent/themes/catppuccin-frappe.json".source = ./themes/catppuccin-frappe.json;
    };

    # Pi updates bookkeeping and extension preference files itself. Merge the
    # declarative portion on every activation rather than making these files
    # read-only Nix store symlinks.
    home.activation.piConfiguration = lib.hm.dag.entryAfter ["linkGeneration"] ''
      ${mergeMutableJson "${agentDirectory}/settings.json" piSettings ".[0] * .[1]"}
      ${mergeMutableJson "${agentDirectory}/effort.json" effortState ".[1] * .[0]"}
      ${mergeMutableJson "${agentDirectory}/priority-routing.json" priorityRoutingState ".[1] * .[0]"}
    '';
  };
}
