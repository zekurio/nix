{inputs, ...}: {
  flake.modules.homeManager.zekurio = {
    lib,
    pkgs,
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
    llmAgents = inputs.llm-agents.packages.${system};
    forcedTelemetryOptOut = "--set PI_SKIP_VERSION_CHECK 1 \\\n  --set PI_TELEMETRY 0";
    pi = llmAgents.pi.overrideAttrs (old: {
      # llm-agents.nix forces PI_TELEMETRY=0, overriding Pi's writable setting
      # and suppressing provider attribution even when the user enables it.
      postInstall =
        if !lib.hasInfix forcedTelemetryOptOut old.postInstall
        then throw "llm-agents.nix no longer forces Pi telemetry off; remove this override"
        else
          builtins.replaceStrings
          [forcedTelemetryOptOut]
          ["--set PI_SKIP_VERSION_CHECK 1"]
          old.postInstall;
    });
  in {
    # Agent CLIs come from llm-agents.nix, pinned in flake.lock and identical
    # on every host. Upgrades and rollbacks happen through the lock (weekly
    # update PR, git revert) and a host rebuild, never imperatively.
    home.packages = [
      llmAgents.codex
      pi
    ];
  };
}
