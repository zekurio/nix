{
  flake.modules.homeManager.zekurio = {
    inputs,
    lib,
    ...
  }: let
    source = "${inputs.agent-stuff}/skills";

    # A skill is any top-level directory holding a SKILL.md, so adding one to
    # agent-stuff reaches every agent after `nix flake update agent-stuff`
    # without touching this file. Pi discovers shared skills through .agents;
    # its package configuration loads the Pi-only zed skill separately.
    available =
      lib.filter (name: builtins.pathExists "${source}/${name}/SKILL.md")
      (builtins.attrNames (builtins.readDir source));

    # The zed skill only pays for itself in the agents driven from Zed, so it is
    # kept out of the shared agent context.
    shared = lib.filter (name: name != "zed") available;

    # Shared skills are linked on their own because the agents expect
    # <directory>/<skill>/SKILL.md. Linking agent-stuff's skills root instead
    # would bury every skill one directory too deep for them.
    linkSkills = directory: skills:
      lib.listToAttrs (map (name:
        lib.nameValuePair "${directory}/${name}" {
          source = "${source}/${name}";
        })
      skills);
  in {
    home.file =
      # Codex's documented user scope.
      linkSkills ".agents/skills" shared
      // linkSkills ".config/opencode/skills" available;

    # Opencode also scans ~/.agents/skills, so every shared skill would be
    # discovered twice. It keys skills by name and resolves the collision by
    # whichever file parses last, which makes the reported skill location flip
    # between sessions and busts the prompt cache (anomalyco/opencode#29950).
    # Confining it to its own directory keeps discovery deterministic.
    home.sessionVariables.OPENCODE_DISABLE_EXTERNAL_SKILLS = "1";
  };
}
