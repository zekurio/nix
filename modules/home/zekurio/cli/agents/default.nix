{
  inputs,
  lib,
  pkgs,
  ...
}: let
  skills = lib.filterAttrs (_: type: type == "directory") (builtins.readDir "${inputs.agent-stuff}/skills");

  # Claude Code reads ~/.claude/skills; Codex reads ~/.agents/skills.
  skillFiles = dir:
    lib.mapAttrs' (name: _:
      lib.nameValuePair "${dir}/${name}" {
        source = "${inputs.agent-stuff}/skills/${name}";
      })
    skills;

  instructions = ''
    This machine is managed with Nix. When a command is missing, use
    `nix run nixpkgs#<pkg> -- <args>` or `nix shell nixpkgs#<pkg> -c <cmd>`.
    In a project with a `flake.nix`, `nix develop -c <cmd>` provides its toolchain.
  '';
in {
  home.file =
    skillFiles ".claude/skills"
    // skillFiles ".agents/skills"
    // {
      ".claude/CLAUDE.md".text = instructions;
      ".codex/AGENTS.md".text = instructions;
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
  # the Nix build; `autoUpdates = false` in ~/.claude.json does not
  # stop native installs.
  home.activation.claudeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    f="$HOME/.claude/settings.json"
    run mkdir -p "$(dirname "$f")"
    [ -s "$f" ] || run sh -c 'echo "{}" > "$1"' _ "$f"
    tmp=$(mktemp)
    ${lib.getExe pkgs.jq} '. * {attribution: {commit: "", pr: "", sessionUrl: false}, autoMemoryEnabled: false, env: {DISABLE_AUTOUPDATER: "1"}}' "$f" > "$tmp" && run mv "$tmp" "$f"
  '';

  # Codex stores the model, trust levels and TUI state in config.toml, so
  # merge here too. tomlq rewrites the whole file and drops any comments in
  # it. Its update check only suggests npm or Homebrew, while flake.lock
  # moves the Nix build.
  home.activation.codexSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    f="$HOME/.codex/config.toml"
    run mkdir -p "$(dirname "$f")"
    [ -e "$f" ] || run touch "$f"
    tmp=$(mktemp)
    ${lib.getExe' pkgs.yq "tomlq"} -t '. * {check_for_update_on_startup: false}' "$f" > "$tmp" && run mv "$tmp" "$f"
  '';
}
