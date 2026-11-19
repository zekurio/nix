{
  config,
  lib,
  pkgs,
  ...
}: let
  # flake.lock moves the CLI; opencode's own updater cannot replace a store
  # path. OpenCode 2 also reads v1's `autoupdate`, but `update` is its own
  # key and wins over it, so the v1 key comes out.
  settings.update = "disable";
in {
  # opencode may write its config itself, so merge the keys in instead of
  # owning the file.
  home.activation.opencodeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    f=${lib.escapeShellArg "${config.xdg.configHome}/opencode/opencode.json"}
    run mkdir -p "$(dirname "$f")"
    [ -s "$f" ] || run sh -c 'echo "{}" > "$1"' _ "$f"
    tmp=$(mktemp)
    ${lib.getExe pkgs.jq} --argjson s ${lib.escapeShellArg (builtins.toJSON settings)} \
      'del(.autoupdate) * $s' "$f" > "$tmp" && run mv "$tmp" "$f"
  '';
}
