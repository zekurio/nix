{
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.homeManager;
in {
  imports = [
    ./base.nix
    ./bitwarden-ssh.nix
    ./dev.nix
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
