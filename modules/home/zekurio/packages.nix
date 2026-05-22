{
  inputs,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
    age
    bat
    btop
    envsubst
    eza
    gh
    git
    jq
    ripgrep
    sops
  ];
}
