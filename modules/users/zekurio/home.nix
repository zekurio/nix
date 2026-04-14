{
  inputs,
  lib,
  ...
}: let
  username = "zekurio";
  baseImports = [
    ./dev.nix
    ./dots.nix
    ./gitconfig.nix
    ./packages.nix
    ./shell.nix
  ];
in {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    sharedModules = [inputs.plasma-manager.homeModules.plasma-manager];
    extraSpecialArgs = {
      inherit inputs;
    };

    users.${username} = {osConfig, ...}: {
      imports =
        baseImports
        ++ lib.optionals (osConfig.modules.desktop.enable or false) [
          ./desktop.nix
          ./plasma.nix
        ];

      fonts.fontconfig.enable = false;

      home = {
        inherit username;
        homeDirectory = "/home/${username}";
        stateVersion = "25.05";
        enableNixpkgsReleaseCheck = false;
      };
    };
  };
}
