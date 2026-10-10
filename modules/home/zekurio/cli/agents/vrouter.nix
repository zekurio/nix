{
  flake.modules.homeManager.zekurio = {
    config,
    lib,
    pkgs,
    ...
  }: let
    url = "https://vrouter.zekurio.me";
    # A vrouter client key, issued in the dashboard and placed by hand on each
    # machine. Both CLIs fetch it with a command: T3 Code and other GUI
    # launches never see shell variables, and the key stays out of the store.
    keyFile = "${config.home.homeDirectory}/.config/vrouter/api-key";
    cat = lib.getExe' pkgs.coreutils "cat";
  in {
    # Both merges wait for the key file. Without it a rebuild would point the
    # CLIs at vrouter with no credential, and Claude Code retries the 401 for
    # minutes before it reports anything. Deleting the key later does not undo
    # a merge; remove the keys from both files to go back to the logins.

    # Runs after claudeSettings, which creates the file. The base URL carries
    # no /v1 because Claude Code appends /v1/messages itself.
    #
    # Claude Code turns MCP tool search off for any base URL that is not
    # Anthropic's and then loads every tool schema upfront. vrouter forwards
    # Claude request bodies and the anthropic-beta header as they arrive, so
    # switch it back on. Drop ENABLE_TOOL_SEARCH here and from settings.json if
    # requests start failing with a 400 that names defer_loading or
    # tool_reference.
    # The fast-mode availability check goes directly to Anthropic, which
    # rejects our gateway key. Let vrouter's upstream account decide instead.
    home.activation.claudeVrouter = lib.hm.dag.entryAfter ["claudeSettings"] ''
      if [ -r '${keyFile}' ]; then
        f="$HOME/.claude/settings.json"
        tmp=$(mktemp)
        ${lib.getExe pkgs.jq} --arg helper '${cat} ${keyFile}' --arg url '${url}' \
          '. * {apiKeyHelper: $helper, env: {ANTHROPIC_BASE_URL: $url, ENABLE_TOOL_SEARCH: "true", CLAUDE_CODE_SKIP_FAST_MODE_ORG_CHECK: "1"}}' "$f" > "$tmp" && run mv "$tmp" "$f"
      fi
    '';

    # Codex stores trust levels and TUI state in config.toml, so merge here
    # too. tomlq rewrites the whole file and drops any comments in it.
    home.activation.codexVrouter = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ -r '${keyFile}' ]; then
        f="$HOME/.codex/config.toml"
        run mkdir -p "$(dirname "$f")"
        [ -e "$f" ] || run touch "$f"
        tmp=$(mktemp)
        ${lib.getExe' pkgs.yq "tomlq"} -t --arg cat '${cat}' --arg key '${keyFile}' --arg url '${url}/v1' \
          '. * {model_provider: "vrouter", model_providers: {vrouter: {name: "vrouter", base_url: $url, auth: {command: $cat, args: [$key]}}}}' "$f" > "$tmp" && run mv "$tmp" "$f"
      fi
    '';
  };
}
