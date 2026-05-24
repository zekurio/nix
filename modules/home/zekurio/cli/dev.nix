{pkgs, ...}: {
  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
  };

  programs.zellij = {
    enable = true;
    enableFishIntegration = false;
  };

  home.packages = [
    pkgs.jujutsu
  ];
}
