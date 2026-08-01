{
  flake.modules.homeManager.zekurio = {
    config,
    inputs,
    lib,
    pkgs,
    ...
  }: let
    agentStuff = pkgs.callPackage ./_agent-stuff.nix {} {
      src = inputs.agent-stuff;
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
        "openai-codex/gpt-5.6-sol"
        "openai-codex/gpt-5.6-terra"
        "openai-codex/gpt-5.6-luna"
        "opencode-go/kimi-k3"
        "opencode-go/glm-5.2"
        "opencode-go/deepseek-v4-flash"
      ];

      # Home Manager provides this local package and its dependencies, so Pi
      # only loads it and never needs npm or Bun to materialize resources.
      packages = ["./packages/agent-stuff"];
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
    home.file.".pi/agent/packages/agent-stuff".source = agentStuff;

    # Pi updates bookkeeping in settings.json itself. Merge the declarative
    # settings rather than making the file a read-only store symlink; package
    # resources remain declarative. Extension-owned state is entirely Pi-managed.
    home.activation.piConfiguration = lib.hm.dag.entryAfter ["linkGeneration"] ''
      ${mergeMutableJson "${agentDirectory}/settings.json" piSettings ".[0] * .[1]"}
    '';
  };
}
