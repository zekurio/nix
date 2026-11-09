{
  config,
  lib,
  pkgs,
  ...
}: let
  jq = lib.getExe pkgs.jq;
  url = lib.escapeShellArg config.agents.vrouter.url;
in {
  # pi reached Anthropic and OpenAI through vrouter until Claude Code and
  # Codex took that over. The modules that did it merged into files pi also
  # writes, so deleting them left their keys behind. This removes them once:
  # the provider entries that point at vrouter, the Fable 5.2 model nested in
  # one of them, and the default and enabled models that named either
  # provider. It only acts while such an entry exists, so an anthropic or
  # openai provider pointed somewhere else later is left alone.
  # Running pi sessions on those models stop working at this activation.
  # Delete this file once lilith, adam and sachiel have each activated it.
  # Ordered after agent-stuff so both edits of settings.json never interleave.
  home.activation.piDropVrouter = lib.hm.dag.entryAfter ["writeBoundary" "agentStuff"] ''
    models="$HOME/.pi/agent/models.json"
    settings="$HOME/.pi/agent/settings.json"
    if [ -s "$models" ] && ${jq} -e --arg url ${url} \
      '[.providers.anthropic.baseUrl, .providers.openai.baseUrl] | any(. != null and startswith($url))' "$models" > /dev/null; then
      tmp=$(mktemp)
      ${jq} --arg url ${url} \
        '.providers |= with_entries(select(((.key == "anthropic" or .key == "openai") and ((.value.baseUrl // "") | startswith($url))) | not))' \
        "$models" > "$tmp" && run chmod 600 "$tmp" && run mv "$tmp" "$models"

      if [ -s "$settings" ]; then
        tmp=$(mktemp)
        ${jq} '
          (if (.defaultProvider // "") | IN("anthropic", "openai") then del(.defaultProvider, .defaultModel) else . end)
          | if has("enabledModels") then
              .enabledModels |= map(select(test("^(anthropic|openai)/") | not))
              | if .enabledModels == [] then del(.enabledModels) else . end
            else . end
        ' "$settings" > "$tmp" && run chmod 600 "$tmp" && run mv "$tmp" "$settings"
      fi
    fi
  '';
}
