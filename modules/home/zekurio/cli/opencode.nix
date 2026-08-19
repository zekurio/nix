{
  flake.modules.homeManager.zekurio = {
    xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";

      # Codex-style yolo: nothing asks for approval. doom_loop is
      # intentionally left at its default ("ask") so the circuit breaker
      # still fires on repeated identical tool calls.
      permission = {
        read = "allow";
        edit = "allow";
        glob = "allow";
        grep = "allow";
        list = "allow";
        bash = "allow";
        task = "allow";
        external_directory = "allow";
        todowrite = "allow";
        question = "allow";
        webfetch = "allow";
        websearch = "allow";
        lsp = "allow";
        skill = "allow";
      };

      # The binary is nix-managed (numtide/llm-agents.nix profile), so
      # opencode must not try to update itself.
      autoupdate = false;
    };
  };
}
