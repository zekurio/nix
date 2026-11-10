{
  lib,
  pkgs,
  ...
}: let
  # No enabledModels: Ctrl+P then cycles through every model /model offers,
  # which agents/vrouter.nix already limits to vrouter's list.
  settings = {
    defaultProvider = "anthropic";
    defaultModel = "claude-opus-5-5";
    defaultThinkingLevel = "high";
  };
in {
  # pi writes settings.json itself, for example when /model saves a new
  # default, so merge these keys instead of owning the file. Each activation
  # resets them; everything else pi or agent-stuff wrote survives. Ordered
  # after agent-stuff so both edits of the file never interleave.
  home.activation.piModels = lib.hm.dag.entryAfter ["writeBoundary" "agentStuff"] ''
    f="$HOME/.pi/agent/settings.json"
    run mkdir -p "$(dirname "$f")"
    [ -s "$f" ] || run sh -c 'echo "{}" > "$1"' _ "$f"
    tmp=$(mktemp)
    ${lib.getExe pkgs.jq} --argjson s ${lib.escapeShellArg (builtins.toJSON settings)} \
      '. * $s' "$f" > "$tmp" && run chmod 600 "$tmp" && run mv "$tmp" "$f"
  '';
}
