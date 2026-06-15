{pkgs, ...}: {
  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
  };

  programs.zellij = {
    enable = true;
    enableFishIntegration = false;
    settings = {
      show_startup_tips = false;
      support_kitty_keyboard_protocol = true;
      copy_command = "wl-copy";
      copy_clipboard = "system";
    };
  };

  home.packages = with pkgs; [
    jujutsu
    devenv
    nil
    nixd
  ];
}
