{
  flake.modules.homeManager.zekurio = {
    inputs,
    lib,
    ...
  }: let
    source = "${inputs.agent-stuff}/skills";

    # A skill is any top-level directory holding a SKILL.md, so adding one to
    # agent-stuff reaches every agent after `nix flake update agent-stuff`
    # without touching this file. Codex, opencode, and Pi all discover skills
    # from ~/.agents/skills.
    available =
      lib.filter (name: builtins.pathExists "${source}/${name}/SKILL.md")
      (builtins.attrNames (builtins.readDir source));
  in {
    # Skills are linked on their own because the agents expect
    # <directory>/<skill>/SKILL.md. Linking agent-stuff's skills root instead
    # would bury every skill one directory too deep for them.
    home.file = lib.listToAttrs (map (name:
      lib.nameValuePair ".agents/skills/${name}" {
        source = "${source}/${name}";
      })
    available);
  };
}
