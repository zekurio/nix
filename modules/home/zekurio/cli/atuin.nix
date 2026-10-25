{
  programs = {
    atuin = {
      enable = true;
      enableFishIntegration = true;
      # The model picker cannot save its choice to the store-backed config,
      # so a selection lasts one session. Set ai.model here to change the
      # default instead.
      settings.ai = {
        enabled = true;
        endpoint = "https://atuin-ai.zekurio.me";
        endpoint_protocol = "oss";
      };
    };

    # The token must stay out of the Nix store. Copy AUTH_TOKEN from adam's
    # atuin_ai_env into this file by hand; Atuin reads ATUIN_AI__API_TOKEN
    # as ai.api_token.
    fish.interactiveShellInit = ''
      if test -r ~/.config/atuin/ai-token
          set -gx ATUIN_AI__API_TOKEN (string trim < ~/.config/atuin/ai-token)
      end
    '';
  };
}
