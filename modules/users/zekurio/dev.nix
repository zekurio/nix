{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
  cfg = config.profiles.dev;
  devPackages = with pkgs; [
    inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
    nil
    nixd
    uv
  ];
in {
  options.profiles.dev.enable =
    lib.mkEnableOption "development packages"
    // {
      default = true;
    };

  config = lib.mkIf cfg.enable {
    home.packages = devPackages;
  };
}
