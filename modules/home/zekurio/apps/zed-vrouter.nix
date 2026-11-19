{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.agents.vrouter;
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
  provider = "Anthropic vrouter";
  gptProvider = "OpenAI vrouter";

  # Zed derives these from the provider names. Keep punctuation out of the
  # names so Fish can import Zed's environment in its integrated terminal.
  keyVariables = ["ANTHROPIC_VROUTER_API_KEY" "OPEN_AI_VROUTER_API_KEY"];
  withKey = pkgs.writeShellScript "zed-vrouter-key" ''
    key=$(${lib.getExe' pkgs.coreutils "tr"} -d '[:space:]' 2>/dev/null < ${lib.escapeShellArg cfg.keyFile}) || key=""
    if [ -n "$key" ]; then
      exec ${lib.getExe' pkgs.coreutils "env"} ${lib.concatMapStringsSep " " (v: ''"${v}=$key"'') keyVariables} "$@"
    fi
    exec "$@"
  '';

  # /v1/models gives each model's display name, context window, output limit
  # and input types, but not Zed's thinking mode or beta headers. Known
  # models carry those here and take only their names from vrouter; the sync
  # builds models vrouter serves beyond this list from the family's defaults
  # and everything vrouter reports.
  claudeDefaults = {
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
  };
  claudeModels = map (model: claudeDefaults // model) [
    {
      name = "claude-fable-5-2";
      extra_beta_headers = ["thinking-binding-controls-2026-08-01"];
    }
    {
      name = "claude-fable-5-1";
      extra_beta_headers = ["thinking-binding-controls-2026-08-01"];
    }
    {
      name = "claude-opus-5-5";
      extra_beta_headers = ["thinking-binding-controls-2026-08-01"];
    }
    {name = "claude-sonnet-5-5";}
    {name = "claude-haiku-5-5";}
  ];
  # Match pi's conservative GPT context budgets. Use Responses, including
  # encrypted reasoning state, so subscription-backed Codex accounts work too.
  gptDefaults = {
    max_tokens = 272000;
    max_output_tokens = 128000;
    reasoning_effort = "high";
    capabilities = {
      tools = true;
      images = true;
      parallel_tool_calls = true;
      prompt_cache_key = true;
      chat_completions = false;
    };
  };
  gptModels = map (name:
    gptDefaults
    // {
      inherit name;
    }
    // lib.optionalAttrs (name == "gpt-5.3-codex") {max_tokens = 400000;}) [
    "gpt-6.2-sol"
    "gpt-6.2-astra"
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
  # The sync adds a served model missing from `models` when its id starts
  # with `prefix`, built from `defaults` and what vrouter reports for it.
  catalog = pkgs.writeText "zed-vrouter-catalog.json" (builtins.toJSON {
    anthropic_compatible.${provider} = {
      legacy_name = "Anthropic (vrouter)";
      prefix = "claude-";
      defaults = claudeDefaults;
      models = claudeModels;
    };
    openai_compatible.${gptProvider} = {
      legacy_name = "OpenAI (vrouter)";
      prefix = "gpt-";
      defaults = gptDefaults;
      models = gptModels;
    };
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
  options.agents.vrouter.zedPackage = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    # The desktop entry runs `zeditor` from PATH, so it gets the key too.
    default = pkgs.symlinkJoin {
      name = "zed-editor-vrouter-${pkgs.zed-editor.version}";
      paths = [pkgs.zed-editor];
      postBuild = ''
        rm "$out/bin/zeditor"
        printf '#!%s\nexec %s %s "$@"\n' ${pkgs.runtimeShell} ${withKey} ${lib.getExe pkgs.zed-editor} > "$out/bin/zeditor"
        chmod +x "$out/bin/zeditor"
      '';
      inherit (pkgs.zed-editor) meta version;
    };
    description = "Zed with the vrouter key in its provider variables, for Linux hosts that install Zed themselves.";
  };

  config.programs.zed-editor = {
    # The sync owns available_models. Keeping it in userSettings would make
    # every activation replace the last good list before trying the network.
    mutableUserSettings = true;
    userSettings.language_models = {
      anthropic_compatible.${provider}.api_url = cfg.url;
      openai_compatible.${gptProvider}.api_url = cfg.url + "/v1";
    };
    userSettings.agent.default_model = {
      inherit provider;
      model = "claude-opus-5-5";
      enable_thinking = true;
      effort = "max";
    };
  };

  config.home.packages = [sync];
  config.home.activation.zedVrouterModels = lib.hm.dag.entryAfter ["zedSettingsActivation"] ''
    run ${lib.getExe sync} || warnEcho "Could not sync Zed's vrouter models; leaving settings unchanged."
  '';

  config.systemd.user = lib.mkIf isLinux {
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

  config.launchd.agents = lib.mkIf isDarwin {
    zed-vrouter-models = {
      enable = true;
      config = {
        ProgramArguments = [(lib.getExe sync)];
        RunAtLoad = true;
        StartInterval = 900;
        ProcessType = "Background";
      };
    };

    # Homebrew's Zed starts from launchd, not a wrapper, so put the key in
    # the launchd user environment that apps opened afterwards inherit. Zed
    # reads it once at launch: one restored at login before this ran, or
    # running across a key change, needs a restart.
    zed-vrouter-key = {
      enable = true;
      config = {
        ProgramArguments = [
          (lib.getExe (pkgs.writeShellApplication {
            name = "zed-vrouter-key";
            text = ''
              # Clear names left in the login session by the old agent.
              /bin/launchctl unsetenv 'ANTHROPIC_(VROUTER)_API_KEY' || :
              /bin/launchctl unsetenv 'OPEN_AI_(VROUTER)_API_KEY' || :
              key=$(tr -d '[:space:]' 2>/dev/null < ${lib.escapeShellArg cfg.keyFile}) || key=""
              for name in ${lib.escapeShellArgs keyVariables}; do
                if [ -n "$key" ]; then
                  /bin/launchctl setenv "$name" "$key"
                else
                  /bin/launchctl unsetenv "$name"
                fi
              done
            '';
          }))
        ];
        RunAtLoad = true;
        WatchPaths = [cfg.keyFile];
        ProcessType = "Background";
      };
    };
  };
}
