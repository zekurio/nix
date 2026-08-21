{inputs, ...}: {
  flake.modules.homeManager.zekurio = {pkgs, ...}: let
    system = pkgs.stdenv.hostPlatform.system;
    llmAgents = inputs.llm-agents.packages.${system};
  in {
    # Agent CLIs come from llm-agents.nix, pinned in flake.lock and identical
    # on every host. Upgrades and rollbacks happen through the lock (weekly
    # update PR, git revert) and a host rebuild, never imperatively.
    home.packages = [
      llmAgents.codex
      llmAgents.opencode
    ];
  };
}
