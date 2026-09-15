{
  flake.modules.homeManager.zekurio = {...}: let
    # Models come from OpenCode Go, the built-in `opencode-go` provider. Its
    # credentials are not part of this config: they live in
    # ~/.local/share/opencode/auth.json, written once by `opencode auth login`.
    settings = {
      "$schema" = "https://opencode.ai/config.json";

      # OpenCode defaults already allow most tools; relax the two guards that
      # ask by default (`external_directory`, `doom_loop`) while keeping the
      # built-in `.env` read block.
      permission = {
        "*" = "allow";
        read = {
          "*" = "allow";
          "*.env" = "deny";
          "*.env.*" = "deny";
          "*.env.example" = "allow";
        };
      };

      # Subagents inherit the caller's model unless pinned. Search and
      # research work does not need a frontier model, so route the built-in
      # subagents to a cheap fast one; only `model` is overridden, the
      # built-in prompts and permissions stay as shipped.
      agent = let
        cheap = "opencode-go/deepseek-v4.1-flash";
      in {
        general.model = cheap;
        explore.model = cheap;
      };
    };
  in {
    home.file.".config/opencode/opencode.jsonc".text = builtins.toJSON settings;
  };
}
