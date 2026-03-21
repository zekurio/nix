{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
  cfg = config.modules.hm.dev;
  devPackages = with pkgs; [
    inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
    nil
    nixd
    uv
  ];
in {
  options.modules.hm.dev = {
    enable =
      lib.mkEnableOption "development packages"
      // {
        default = true;
      };
  };

  config = lib.mkIf cfg.enable {
    home.packages = devPackages;
  };
}
