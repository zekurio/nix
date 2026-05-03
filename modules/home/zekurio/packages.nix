{pkgs, ...}: {
  home.packages = with pkgs; [
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
