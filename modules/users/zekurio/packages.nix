{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.profiles.packages;
  cliPackages = with pkgs; [
    age
    bat
    btop
    envsubst
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

  config = {
    home.sessionPath = [
      "$HOME/.local/bin"
    ];

    home.packages = lib.optionals cfg.cli.enable cliPackages;
  };
}
