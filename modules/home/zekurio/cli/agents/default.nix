{inputs, ...}: {
  flake.modules.homeManager.zekurio = {
    lib,
    pkgs,
    ...
  }: let
    skills = lib.filterAttrs (_: type: type == "directory") (builtins.readDir "${inputs.agent-stuff}/skills");
  in {
    home.file =
      lib.mapAttrs' (name: _:
        lib.nameValuePair ".claude/skills/${name}" {
          source = "${inputs.agent-stuff}/skills/${name}";
        })
      skills
      // {
        ".claude/CLAUDE.md".text = ''
          This machine is managed with Nix. When a command is missing, use
          `nix run nixpkgs#<pkg> -- <args>` or `nix shell nixpkgs#<pkg> -c <cmd>`.
          In a project with a `flake.nix`, `nix develop -c <cmd>` provides its toolchain.
        '';
      };

    # Claude Code writes to ~/.claude/settings.json itself (/model, /config),
    # so merge our keys in instead of owning the file as a read-only symlink.
    # Empty `commit`/`pr` drop the Co-Authored-By trailer and the PR footer;
    # `sessionUrl = false` drops the `Claude-Session` trailer and PR link
    # that cloud and Remote Control sessions add on top of those.
    # `autoMemoryEnabled = false` stops Claude from reading and writing
    # memories.
    # The Nix wrapper sets DISABLE_AUTOUPDATER too, but a binary started
    # without it installs a self-updating copy into ~/.local/bin that shadows
    # the agents profile; `autoUpdates = false` in ~/.claude.json does not
    # stop native installs.
    home.activation.claudeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
      f="$HOME/.claude/settings.json"
      run mkdir -p "$(dirname "$f")"
      [ -s "$f" ] || run sh -c 'echo "{}" > "$1"' _ "$f"
      tmp=$(mktemp)
      ${lib.getExe pkgs.jq} '. * {attribution: {commit: "", pr: "", sessionUrl: false}, autoMemoryEnabled: false, env: {DISABLE_AUTOUPDATER: "1"}}' "$f" > "$tmp" && run mv "$tmp" "$f"
    '';
  };
}
