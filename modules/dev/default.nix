{
  lib,
  config,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.modules.dev;
in {
  imports = [
    ./git.nix
  ];

  options.modules.dev.enable = lib.mkEnableOption "development tools and git config";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
      pkgs.nil
      pkgs.nixd
      pkgs.uv
    ];
  };
}
