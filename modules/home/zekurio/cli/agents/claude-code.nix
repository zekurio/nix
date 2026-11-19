{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.agents.vrouter;

  # The helper's output goes out as both x-api-key and a bearer token, and
  # vrouter accepts either. It outranks a stored /login, so the login can
  # stay. Claude Code reruns the helper after five minutes or a 401, so a
  # replaced key needs no restart.
  #
  # With discovery on, Claude Code reads vrouter's /v1/models at startup and
  # adds its Claude models to /model, beside the built-in aliases.
  vrouter = {
    apiKeyHelper = "${lib.getExe' pkgs.coreutils "cat"} ${lib.escapeShellArg cfg.keyFile}";
    env = {
      ANTHROPIC_BASE_URL = cfg.url;
      CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY = "1";
    };
  };
in {
  # Claude Code writes settings.json itself, for example when /model saves a
  # default, so merge the keys in instead of owning the file. Without a key
  # they come out again and Claude Code falls back to its /login. Only values
  # this module wrote are removed.
  home.activation.claudeCodeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    f="$HOME/.claude/settings.json"
    run mkdir -p "$(dirname "$f")"
    [ -s "$f" ] || run sh -c 'echo "{}" > "$1"' _ "$f"
    tmp=$(mktemp)
    if [ -s ${lib.escapeShellArg cfg.keyFile} ]; then
      filter='. * $v'
    else
      filter='del(.apiKeyHelper | select(. == $v.apiKeyHelper))
        | if (.env | type) == "object" then
            .env |= with_entries(select(.value != $v.env[.key]))
            | if .env == {} then del(.env) else . end
          else . end'
    fi
    ${lib.getExe pkgs.jq} --argjson v ${lib.escapeShellArg (builtins.toJSON vrouter)} "$filter" "$f" > "$tmp" \
      && run chmod 600 "$tmp" && run mv "$tmp" "$f"
  '';
}
