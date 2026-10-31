{pkgs, ...}: {
  home.packages = with pkgs; [
    age
    devenv
    envsubst
    gh
    jq
    nil
    nixd
    nodejs
    ripgrep
    sops
  ];
}
