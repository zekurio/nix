{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.agents.vrouter;
  keyFile = lib.escapeShellArg cfg.keyFile;
  cat = lib.getExe' pkgs.coreutils "cat";
in {
  options.agents.vrouter = {
    url = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "https://vrouter.zekurio.me";
      description = "vrouter origin. Anthropic clients append /v1/messages themselves; OpenAI clients need /v1.";
    };

    # Issued on vrouter's API keys page and placed by hand on each machine.
    # Every client reads it with a command: T3 Code and other GUI launches
    # never see shell variables, and the key stays out of the store.
    keyFile = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${config.home.homeDirectory}/.config/vrouter/api-key";
      description = "vrouter client key for this machine.";
    };
  };

  # Both merges wait for the key file. Without it a rebuild would point the
  # CLIs at vrouter with no credential, and Claude Code retries the 401 for
  # minutes before it reports anything. Deleting the key later does not undo
  # a merge; README.md lists the keys to remove to go back to the logins.
  config.home.activation = {
    # Claude Code turns MCP tool search off for any base URL that is not
    # Anthropic's and then loads every tool schema upfront. vrouter forwards
    # Claude request bodies and the anthropic-beta header as they arrive, so
    # switch it back on. Drop ENABLE_TOOL_SEARCH if requests start failing
    # with a 400 that names defer_loading or tool_reference.
    # The fast-mode availability check goes directly to Anthropic, which
    # rejects a vrouter key, so skip it and let the upstream account decide.
    claudeVrouter = lib.hm.dag.entryAfter ["claudeSettings"] ''
      if [ -r ${keyFile} ]; then
        f="$HOME/.claude/settings.json"
        tmp=$(mktemp)
        ${lib.getExe pkgs.jq} --arg helper ${lib.escapeShellArg "${cat} ${keyFile}"} --arg url ${lib.escapeShellArg cfg.url} \
          '. * {apiKeyHelper: $helper, env: {ANTHROPIC_BASE_URL: $url, ENABLE_TOOL_SEARCH: "true", CLAUDE_CODE_SKIP_FAST_MODE_ORG_CHECK: "1"}}' "$f" > "$tmp" && run mv "$tmp" "$f"
      fi
    '';

    # A custom provider needs no OpenAI login, so T3 Code skips that check.
    # The model catalog sits in the agents profile so that it follows the
    # Codex build agents-update installs; packages/agents.nix explains it.
    codexVrouter = lib.hm.dag.entryAfter ["codexSettings"] ''
      if [ -r ${keyFile} ]; then
        f="$HOME/.codex/config.toml"
        tmp=$(mktemp)
        ${lib.getExe' pkgs.yq "tomlq"} -t --arg cat ${cat} --arg key ${keyFile} --arg url ${lib.escapeShellArg "${cfg.url}/v1"} \
          --arg catalog ${lib.escapeShellArg "${config.agents.profile}/share/codex/models.json"} \
          '. * {model_provider: "vrouter", model_catalog_json: $catalog, model_providers: {vrouter: {name: "vrouter", base_url: $url, auth: {command: $cat, args: [$key]}}}}' "$f" > "$tmp" && run mv "$tmp" "$f"
      fi
    '';
  };
}
