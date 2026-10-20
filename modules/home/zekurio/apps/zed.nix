let
  vrouterUrl = "https://vrouter.zekurio.me";
in {
  flake.modules.homeManager.zekurio = {
    # Config only; the binary comes from the host.
    programs.zed-editor = {
      enable = true;
      package = null;
      extensions = [
        "astro"
        "dockerfile"
        "git-firefly"
        "html"
        "java"
        "kotlin"
        "log"
        "make"
        "nix"
        "qml"
        "sql"
        "toml"
        "xml"
      ];
      # Enter the key from ~/.config/vrouter/api-key in each provider's Zed
      # settings. Zed stores it in the system keychain, outside the Nix store.
      userSettings.language_models = {
        anthropic_compatible."Anthropic (vrouter)" = {
          api_url = vrouterUrl;
          available_models = map (model:
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
        };
      };
      userSettings.agent.default_model = {
        provider = "Anthropic (vrouter)";
        model = "claude-opus-5-5";
        enable_thinking = true;
        effort = "max";
      };
    };
  };
}
