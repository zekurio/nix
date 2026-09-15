{
  flake.modules.homeManager.zekurio = {...}: let
    # CLIProxyAPI runs on adam behind the private Caddy vhost
    # `cpa.zekurio.me` (LAN + tailnet only). The API key is not part of this
    # config: it lives in ~/.local/share/opencode/auth.json, written once by
    # `/connect` (or `opencode auth login`).
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

      provider.cliproxyapi = {
        npm = "@ai-sdk/openai-compatible";
        name = "CLIProxyAPI";
        options.baseURL = "https://cpa.zekurio.me/v1";
        # IDs must match `GET /v1/models` on the proxy.
        models = let
          model = name: {
            inherit name;
            reasoning = true;
          };
        in {
          "claude-fable-5-1" = model "Claude Fable 5.1";
          "claude-opus-5" = model "Claude Opus 5";
          "claude-sonnet-5" = model "Claude Sonnet 5";
        };
      };
    };
  in {
    home.file.".config/opencode/opencode.jsonc".text = builtins.toJSON settings;
  };
}
