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
      models.providers.openai-codex.models = [
        {
          id = "gpt-5.6-sol-1m";
          name = "GPT-5.6 Sol (1M)";
          api = "openai-codex-responses";
          reasoning = true;
          input = [
            "text"
            "image"
          ];
          cost = {
            input = 5;
            output = 30;
            cacheRead = 0.5;
            cacheWrite = 6.25;
            tiers = [
              {
                inputTokensAbove = 272000;
                input = 10;
                output = 45;
                cacheRead = 1;
                cacheWrite = 12.5;
              }
            ];
          };
          contextWindow = 1050000;
          maxTokens = 128000;
          thinkingLevelMap = {
            minimal = "low";
            xhigh = "xhigh";
            max = "max";
          };
          compat = {
            supportsOpenAIGrammarTools = true;
            supportsAdditionalTools = true;
            supportsToolSearch = true;
          };
        }
      ];
    };
  };
}
