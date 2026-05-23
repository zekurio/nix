{pkgs, ...}: {
  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
  };

  programs.zellij = {
    enable = true;
    enableFishIntegration = true;
  };

  home.packages = [
    pkgs.jujutsu
  ];
}
