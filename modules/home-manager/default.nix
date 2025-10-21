{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkEnableOption mkDefault mkIf;
  cfg = config.modules.homeManager;
in
{
  imports = [
    ./base.nix
    ./git.nix
  ];

  options.modules.homeManager = {
    enable =
      mkEnableOption "Home manager configuration for zekurio"
      // {
        default = true;
      };
  };

  config = mkIf cfg.enable {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
    };
  };
}
