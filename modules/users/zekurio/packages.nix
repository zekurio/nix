{
  config,
  lib,
  pkgs,
  ...
}: let
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
  options.profiles.packages.cli.enable =
    lib.mkEnableOption "day-to-day CLI/sysadmin packages"
    // {
      default = true;
    };

  config = lib.mkIf config.profiles.packages.cli.enable {
    home.packages = cliPackages;

    home.sessionPath = [
      "$HOME/.local/bin"
    ];
  };
}
