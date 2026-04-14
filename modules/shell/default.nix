{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.modules.shell;
in {
  imports = [
    ./fish.nix
    ./prompt.nix
  ];

  options.modules.shell.enable = lib.mkEnableOption "shell and CLI tools";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
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
  };
}
