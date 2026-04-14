{pkgs, ...}: let
  cliPackages = with pkgs; [
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
    zellij
  ];
in {
  home.packages = cliPackages;

  home.sessionPath = [
    "$HOME/.local/bin"
  ];
}
