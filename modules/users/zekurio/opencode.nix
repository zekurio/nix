{
  lib,
  osConfig,
  inputs,
  pkgs,
  ...
}: {
  config = lib.mkIf (osConfig.modules.dev.enable or false) {
    programs.opencode = {
      enable = true;
      package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
      settings = {
        plugin = ["opencode-anthropic-auth"];
      };
    };
  };
}
