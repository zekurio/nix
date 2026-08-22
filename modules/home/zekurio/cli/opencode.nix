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

      # Permit one coordinator layer between the primary agent and specialists.
      subagent_depth = 2;

      agent.plan.disable = true;

      agent.design = {
        description = "Designs specifications and resolves requirements before implementation.";
        mode = "primary";
        prompt = ''
          Work with the user to design a clear specification before implementation.
          Explore goals, constraints, tradeoffs, edge cases, and acceptance criteria.
          Ask focused questions when decisions materially affect the design. Use
          specialists and shell-based research when useful. Clone external
          repositories only into temporary locations. Do not implement the design
          or modify the active workspace.
        '';
        permission = {
          edit = "deny";
          bash = "allow";
          task = {
            "*" = "deny";
            explore = "allow";
            review = "allow";
            scout = "allow";
            vision = "allow";
          };
        };
      };

      agent.ramble = {
        description = "Discusses rough ideas, possibilities, and what-ifs without implementing them.";
        mode = "primary";
        prompt = ''
          Be a thoughtful conversational partner for open-ended ideas and
          what-ifs. Help the user discover possibilities, challenge assumptions,
          and connect related thoughts without forcing the conversation into a
          formal plan. Use shell-based research when useful, cloning external
          repositories only into temporary locations. Do not implement ideas or
          modify the active workspace.
        '';
        permission = {
          edit = "deny";
          bash = "allow";
          task = {
            "*" = "deny";
            explore = "allow";
            scout = "allow";
            vision = "allow";
          };
        };
      };

      agent.general = {
        model = "openai/gpt-5.6-luna";
        variant = "max";
      };

      agent.explore = {
        model = "openai/gpt-5.6-luna";
        variant = "max";
      };

      agent.review = {
        description = "Reviews code for bugs, regressions, security risks, and missing tests.";
        mode = "subagent";
        model = "kimi-for-coding/k3";
        variant = "max";
        prompt = ''
          Review the requested changes without modifying the workspace. Prioritize
          concrete bugs, behavioral regressions, security risks, and missing tests.
          Report findings first, ordered by severity, with file and line references.
          Delegate codebase discovery to explore and external research to scout.
        '';
        permission = {
          edit = "deny";
          bash = "deny";
          task = {
            "*" = "deny";
            explore = "allow";
            scout = "allow";
            vision = "allow";
          };
        };
      };

      agent.vision = {
        description = "Inspects image files and reports visual details to other agents.";
        mode = "subagent";
        model = "openai/gpt-5.6-luna";
        variant = "max";
        prompt = ''
          Inspect the image files requested by the calling agent. Use the read
          tool to load each image, then return an accurate description focused
          on the caller's question. Do not modify files.
        '';
        permission = {
          edit = "deny";
          bash = "deny";
          task = "deny";
        };
      };

      # The binary is nix-managed (numtide/llm-agents.nix profile), so
      # opencode must not try to update itself.
      autoupdate = false;
    };
  };
}
