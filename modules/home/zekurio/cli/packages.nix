{
  inputs,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    age
    devenv
    envsubst
    eza
    gh
    git
    git-lfs
    jujutsu
    jq
    nil
    nixd
    ripgrep
    sops
  ];
}
