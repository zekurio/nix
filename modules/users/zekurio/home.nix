{inputs, ...}: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs;
    };

    users.zekurio = {
      imports = [
        ./desktop.nix
        ./dev.nix
        ./dots.nix
        ./gitconfig.nix
        ./packages.nix
        ./shell.nix
        ./ssh.nix
      ];

      fonts.fontconfig.enable = false;

      home = {
        username = "zekurio";
        homeDirectory = "/home/zekurio";
        stateVersion = "25.05";
        enableNixpkgsReleaseCheck = false;
      };
    };
  };
}
