{
  lib,
  pkgs,
  ...
}: {
  # Claude Code, Codex and opencode are T3 Code's agents here. The opencode
  # driver ships disabled; pi's entry comes out with pi.
  # T3 Code updates a provider with the provider's own updater, which would
  # install a copy beside the Nix build. With update checks off, T3 Code
  # never reports a provider as outdated, and flake.lock moves the CLIs
  # instead.
  # The server rewrites settings.json when settings change in its UI, so
  # merge the keys in instead of owning the file as a read-only symlink.
  home.activation.t3codeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    f="$HOME/.t3/userdata/settings.json"
    run mkdir -p "$(dirname "$f")"
    [ -s "$f" ] || run sh -c 'echo "{}" > "$1"' _ "$f"
    tmp=$(mktemp)
    ${lib.getExe pkgs.jq} '. * {
      enableProviderUpdateChecks: false,
      providerInstances: {
        codex: {driver: "codex", enabled: true},
        claudeAgent: {driver: "claudeAgent", enabled: true},
        opencode: {driver: "opencode", enabled: true}
      }
    } | del(.providerInstances.pi)' "$f" > "$tmp" && run mv "$tmp" "$f"
  '';
}
