{inputs, ...}: {
  flake.modules.homeManager.zekurio = {pkgs, ...}: {
    # Agent CLIs come from llm-agents.nix, pinned in flake.lock and identical
    # on every host. Upgrades and rollbacks happen through the lock (weekly
    # update PR, git revert) and a host rebuild, never imperatively.
    home.packages = [inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex];
  };
}
