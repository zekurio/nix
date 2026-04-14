{
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
  home.packages = devPackages;
}
