{inputs, ...}: {
  flake.modules.homeManager.zekurio = {
    lib,
    pkgs,
    ...
  }: {
    # Codex comes from llm-agents.nix, pinned in flake.lock and identical
    # on every host. Upgrades and rollbacks happen through the lock (weekly
    # update PR, git revert) and a host rebuild, never imperatively.
    home.file = lib.mapAttrs' (name: _:
      lib.nameValuePair ".agents/skills/${name}" {
        source = "${inputs.agent-stuff}/skills/${name}";
      }) (lib.filterAttrs (_: type: type == "directory") (builtins.readDir "${inputs.agent-stuff}/skills"));

    home.packages = [inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex];
  };
}
