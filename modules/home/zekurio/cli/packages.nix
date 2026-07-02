{
  inputs,
  pkgs,
  ...
}: {
  home.packages = with pkgs;
    [
      age
      bitwarden-cli
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
    ]
    ++ [
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
    ];
}
