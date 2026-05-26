{
  inputs,
  pkgs,
  ...
}: {
  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
  };

  programs.zellij = {
    enable = true;
    enableFishIntegration = false;
    settings = {
      theme = "catppuccin-frappe";
      show_startup_tips = false;
    };
  };

  home.file.".config/zellij/themes/catppuccin.kdl".source = "${inputs.catppuccin-zellij}/catppuccin.kdl";

  home.packages = [
    pkgs.jujutsu
  ];
}
