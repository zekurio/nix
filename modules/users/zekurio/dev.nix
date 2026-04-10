{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
  cfg = config.profiles.dev;
  devPackages = with pkgs; [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code-acp
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex-acp
    nil
    nixd
    uv
  ];
in {
  options.profiles.dev.enable =
    lib.mkEnableOption "development packages"
    // {
      default = true;
    };

  config = lib.mkIf cfg.enable {
    home.packages = devPackages;
  };
}
