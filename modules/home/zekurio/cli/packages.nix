{
  inputs,
  lib,
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
    ++ lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp
    ];
}
