{
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = [
    pkgs.ghostty
  ];

  home-manager.users.zekurio.programs.ghostty.settings.font-size = lib.mkForce 11.5;
}
