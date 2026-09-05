{inputs, ...}: {
  flake.modules.homeManager.zekurio = {
    lib,
    pkgs,
    ...
  }: let
    pi = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi.overrideAttrs (old: let
      forcedTelemetryOptOut = "--set PI_SKIP_VERSION_CHECK 1 \\\n  --set PI_TELEMETRY 0";
    in {
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
    imports = [inputs.agent-stuff.homeManagerModules.default];
    programs.agent-stuff.enable = true;

    programs.pi-coding-agent = {
      enable = true;
      package = pi;
    };
  };
}
