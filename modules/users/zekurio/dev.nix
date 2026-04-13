{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  devPackages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
    pkgs.nil
    pkgs.nixd
    pkgs.uv
  ];
in {
  options.profiles.dev.enable =
    lib.mkEnableOption "development packages"
    // {
      default = true;
    };

  config = lib.mkIf config.profiles.dev.enable {
    home.packages = devPackages;
  };
}
