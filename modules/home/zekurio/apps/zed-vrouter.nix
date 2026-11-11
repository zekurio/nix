{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.agents.vrouter;
  provider = "Anthropic (vrouter)";
  # /v1/models identifies available models, but does not describe thinking,
  # output limits or beta headers. Keep those here and omit unknown models.
  claudeModels = map (model:
    {
      max_tokens = 1000000;
      # Thinking and the visible reply share the documented 128K limit.
      max_output_tokens = 128000;
      mode.type = "adaptive";
      extra_beta_headers = [];
      capabilities = {
        tools = true;
        images = true;
        prompt_caching = true;
      };
    }
    // model) [
    {
      name = "claude-fable-5-2";
      display_name = "Claude Fable 5.2";
      extra_beta_headers = ["thinking-binding-controls-2026-08-01"];
    }
    {
      name = "claude-fable-5-1";
      display_name = "Claude Fable 5.1";
      extra_beta_headers = ["thinking-binding-controls-2026-08-01"];
    }
    {
      name = "claude-opus-5-5";
      display_name = "Claude Opus 5.5";
      extra_beta_headers = ["thinking-binding-controls-2026-08-01"];
    }
    {
      name = "claude-sonnet-5-5";
      display_name = "Claude Sonnet 5.5";
    }
    {
      name = "claude-haiku-5-5";
      display_name = "Claude Haiku 5.5";
    }
  ];
  # Match pi's conservative GPT context budgets. Use Responses, including
  # encrypted reasoning state, so subscription-backed Codex accounts work too.
  gptModels =
    map (name: {
      inherit name;
      max_tokens =
        if name == "gpt-5.3-codex"
        then 400000
        else 272000;
      max_output_tokens = 128000;
      reasoning_effort = "high";
      capabilities = {
        tools = true;
        images = true;
        parallel_tool_calls = true;
        prompt_cache_key = true;
        chat_completions = false;
      };
    }) [
      "gpt-6.1-sol"
      "gpt-6.1-terra"
      "gpt-6-astra"
      "gpt-6-sol"
      "gpt-6-luna"
      "gpt-5.6-cyber"
      "gpt-5.6-sol"
      "gpt-5.6-terra"
      "gpt-5.6-luna"
      "gpt-5.3-codex"
    ];
  catalog = pkgs.writeText "zed-vrouter-catalog.json" (builtins.toJSON {
    anthropic_compatible.${provider} = claudeModels;
    openai_compatible."OpenAI (vrouter)" = gptModels;
  });
  sync = pkgs.writeShellApplication {
    name = "zed-vrouter-models";
    runtimeInputs = [(pkgs.python3.withPackages (ps: [ps.json5]))];
    text = ''
      exec python3 ${./zed-vrouter-models.py} \
        --catalog ${catalog} \
        --url ${lib.escapeShellArg cfg.url} \
        --key-file ${lib.escapeShellArg cfg.keyFile} \
        --settings ${lib.escapeShellArg "${config.xdg.configHome}/zed/settings.json"} \
        "$@"
    '';
  };
in {
  programs.zed-editor = {
    # The sync owns available_models. Keeping it in userSettings would make
    # every activation replace the last good list before trying the network.
    mutableUserSettings = true;
    userSettings.language_models = {
      anthropic_compatible.${provider}.api_url = cfg.url;
      openai_compatible."OpenAI (vrouter)".api_url = cfg.url + "/v1";
    };
    # Enter the key from agents.vrouter.keyFile in each provider's Zed
    # settings. Zed stores it in the system keychain, outside the Nix store.
    userSettings.agent.default_model = {
      inherit provider;
      model = "claude-opus-5-5";
      enable_thinking = true;
      effort = "max";
    };
  };

  home.packages = [sync];
  home.activation.zedVrouterModels = lib.hm.dag.entryAfter ["zedSettingsActivation"] ''
    run ${lib.getExe sync} || warnEcho "Could not sync Zed's vrouter models; leaving settings unchanged."
  '';

  systemd.user = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    services.zed-vrouter-models = {
      Unit.Description = "Sync Zed's Claude and GPT models from vrouter";
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe sync;
      };
    };
    timers.zed-vrouter-models = {
      Unit.Description = "Refresh Zed's vrouter model list";
      Timer = {
        OnStartupSec = "1min";
        OnUnitActiveSec = "15min";
      };
      Install.WantedBy = ["timers.target"];
    };
  };

  launchd.agents.zed-vrouter-models = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [(lib.getExe sync)];
      RunAtLoad = true;
      StartInterval = 900;
      ProcessType = "Background";
    };
  };
}
