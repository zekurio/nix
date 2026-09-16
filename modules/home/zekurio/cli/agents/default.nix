{inputs, ...}: {
  flake.modules.homeManager.zekurio = {
    lib,
    pkgs,
    ...
  }: let
    llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
    skills = lib.filterAttrs (_: type: type == "directory") (builtins.readDir "${inputs.agent-stuff}/skills");
    # Claude Code reads ~/.claude/skills, and OpenCode reads both directories.
    skillDirs = [".agents/skills" ".claude/skills"];
    linkSkills = dir:
      lib.mapAttrs' (name: _:
        lib.nameValuePair "${dir}/${name}" {
          source = "${inputs.agent-stuff}/skills/${name}";
        })
      skills;
  in {
    # Claude Code, Codex, and OpenCode come from llm-agents.nix, pinned in
    # flake.lock and identical on every host. Upgrades and rollbacks happen
    # through the lock (weekly update PR, git revert) and a host rebuild, never
    # imperatively.
    home.packages = [
      llmAgents.claude-code
      llmAgents.codex
      llmAgents.opencode
    ];

    home.file = lib.mkMerge (map linkSkills skillDirs);

    # Claude Code writes to ~/.claude/settings.json itself (/model, /config),
    # so merge our keys in instead of owning the file as a read-only symlink.
    # Empty `commit`/`pr` drop the Co-Authored-By trailer and the PR footer;
    # `sessionUrl = false` drops the `Claude-Session` trailer and PR link
    # that cloud and Remote Control sessions add on top of those.
    home.activation.claudeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
      f="$HOME/.claude/settings.json"
      run mkdir -p "$(dirname "$f")"
      [ -s "$f" ] || run sh -c 'echo "{}" > "$1"' _ "$f"
      tmp=$(mktemp)
      ${lib.getExe pkgs.jq} '. * {attribution: {commit: "", pr: "", sessionUrl: false}}' "$f" > "$tmp" && run mv "$tmp" "$f"
    '';
  };
}
