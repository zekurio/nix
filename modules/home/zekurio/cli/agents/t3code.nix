{
  lib,
  pkgs,
  ...
}: {
  # T3 Code updates a provider with the provider's own updater. For the Nix
  # build of Claude Code that is `claude update`, which installs a native
  # copy beside the agents profile. With update checks off, T3 Code never
  # reports a provider as outdated, and agents-update moves the CLIs instead.
  # The server then uses the model catalog bundled with its build, so new
  # models arrive with the next T3 Code release.
  # The server rewrites settings.json when settings change in its UI, so
  # merge the key in instead of owning the file as a read-only symlink.
  home.activation.t3codeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    f="$HOME/.t3/userdata/settings.json"
    run mkdir -p "$(dirname "$f")"
    [ -s "$f" ] || run sh -c 'echo "{}" > "$1"' _ "$f"
    tmp=$(mktemp)
    ${lib.getExe pkgs.jq} '. * {enableProviderUpdateChecks: false}' "$f" > "$tmp" && run mv "$tmp" "$f"
  '';
}
