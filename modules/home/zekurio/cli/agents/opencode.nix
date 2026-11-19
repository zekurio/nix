{
  config,
  lib,
  pkgs,
  ...
}: let
  # flake.lock moves the CLI; opencode's own updater cannot replace a store
  # path.
  settings = {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
  };
in {
  # opencode may write its config itself, so merge the keys in instead of
  # owning the file.
  home.activation.opencodeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    f=${lib.escapeShellArg "${config.xdg.configHome}/opencode/opencode.json"}
    run mkdir -p "$(dirname "$f")"
    [ -s "$f" ] || run sh -c 'echo "{}" > "$1"' _ "$f"
    tmp=$(mktemp)
    ${lib.getExe pkgs.jq} --argjson s ${lib.escapeShellArg (builtins.toJSON settings)} \
      '. * $s' "$f" > "$tmp" && run mv "$tmp" "$f"
  '';
}
