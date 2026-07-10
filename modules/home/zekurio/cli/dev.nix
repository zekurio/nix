{pkgs, ...}: let
  copyCommand =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "pbcopy"
    else "${pkgs.wl-clipboard}/bin/wl-copy";
in {
  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.zellij = {
    enable = true;
    enableFishIntegration = false;
    settings = {
      show_startup_tips = false;
      support_kitty_keyboard_protocol = true;
      copy_command = copyCommand;
      copy_clipboard = "system";
    };
  };

  catppuccin.zellij.enable = true;
}
