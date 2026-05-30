{
  inputs,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    age
    envsubst
    eza
    gh
    git
    git-lfs
    jq
    ripgrep
    sops
  ];
}
