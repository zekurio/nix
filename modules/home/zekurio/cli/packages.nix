{pkgs, ...}: {
  home.packages = with pkgs; [
    age
    bitwarden-cli
    devenv
    envsubst
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
