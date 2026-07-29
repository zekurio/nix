{
  flake.modules.homeManager.zekurio = {
    inputs,
    pkgs,
    ...
  }: let
    agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  in {
    # Every agent here ships a compiled binary with its runtime embedded, so
    # none of them needs a global node or bun on the host.
    home.packages = with agents; [
      claude-code
      codex
      opencode
      pi
    ];
  };
}
