{
  config,
  inputs,
  lib,
  ...
}: let
  instructions = ''
    This machine is managed with Nix. When a command is missing, use
    `nix run nixpkgs#<pkg> -- <args>` or `nix shell nixpkgs#<pkg> -c <cmd>`.
    In a project with a `flake.nix`, `nix develop -c <cmd>` provides its toolchain.
  '';

  # Codex and opencode read the skills from ~/.agents/skills, where
  # agent-stuff links them. Claude Code only reads ~/.claude/skills.
  # opencode reads both and logs each skill as a duplicate; the copies are
  # identical, so either one wins.
  skills =
    lib.attrNames (lib.filterAttrs (_: type: type == "directory")
      (builtins.readDir "${inputs.agent-stuff}/skills"));
in {
  imports = [inputs.agent-stuff.homeManagerModules.default];

  programs.agent-stuff.enable = true;

  home.file =
    lib.listToAttrs (map (name:
      lib.nameValuePair ".claude/skills/${name}" {
        source = "${config.programs.agent-stuff.package}/skills/${name}";
      })
    skills)
    // {
      ".claude/CLAUDE.md".text = instructions;
      ".codex/AGENTS.md".text = instructions;
    };

  xdg.configFile."opencode/AGENTS.md".text = instructions;
}
