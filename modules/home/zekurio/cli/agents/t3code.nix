{
  lib,
  pkgs,
  ...
}: {
  # pi is T3 Code's only agent here. Its driver ships disabled, and the
  # default codex and claudeAgent instances would otherwise report missing
  # binaries.
  # T3 Code updates a provider with the provider's own updater. For pi that
  # is `pi update --self`, which installs a copy beside the Nix build. With
  # update checks off, T3 Code never reports a provider as outdated, and
  # flake.lock moves the CLI instead.
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
        pi: {driver: "pi", enabled: true},
        codex: {driver: "codex", enabled: false},
        claudeAgent: {driver: "claudeAgent", enabled: false}
      }
    }' "$f" > "$tmp" && run mv "$tmp" "$f"
  '';
}
