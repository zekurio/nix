{
  lib,
  pkgs,
  ...
}: {
  # pi's driver ships disabled, and the codex and claudeAgent instances were
  # switched off here while pi was the only agent, so all three are set
  # explicitly. pi lists no models until a provider is configured for it.
  # T3 Code updates a provider with the provider's own updater. For the Nix
  # builds that is `claude update` or `pi update --self`, which installs a
  # copy beside the Nix build. With update checks off, T3 Code never reports
  # a provider as outdated, and flake.lock moves the CLIs instead.
  # The server then uses the model catalog bundled with its build, so new
  # Claude models arrive with the next T3 Code release. Codex and pi report
  # their own models.
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
        codex: {driver: "codex", enabled: true},
        claudeAgent: {driver: "claudeAgent", enabled: true}
      }
    }' "$f" > "$tmp" && run mv "$tmp" "$f"
  '';
}
