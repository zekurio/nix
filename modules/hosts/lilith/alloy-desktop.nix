{inputs, ...}: {
  imports = [inputs.alloy.nixosModules.desktop];

  programs.alloy-desktop.enable = true;
}
