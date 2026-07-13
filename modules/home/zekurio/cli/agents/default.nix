{
  inputs,
  pkgs,
  ...
}: let
  agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in {
  home.packages = with agents; [
    claude-code
    codex
  ];
}
