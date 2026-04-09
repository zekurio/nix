{
  pkgs,
  inputs,
  ...
}: {
  nix.settings.trusted-users = ["zekurio"];

  programs.vim = {
    enable = true;
    defaultEditor = true;
  };

  environment.shells = [pkgs.nushell];

  users = {
    defaultUserShell = pkgs.nushell;

    users.zekurio = {
      shell = pkgs.nushell;
      uid = 1000;
      isNormalUser = true;
      hashedPassword = "$y$j9T$F7RSP23wOrzzmEJcTxY98.$i58fRl1nIbPjOZ4jBxLu/FWJb/i/DEytiWVtMxcd5G8";
      extraGroups = [
        "wheel"
        "users"
        "video"
        "podman"
        "input"
        "i2c"
      ];
      group = "zekurio";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOXuY93/KsNdn9B9LW4JwPGpHa5d5W0XHYttP5wdHDb8 zekurio@termius"
      ];
    };

    groups.zekurio = {
      gid = 1000;
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs;
    };

    users.zekurio = {
      imports = [
        ./dev.nix
        ./dots.nix
        ./gitconfig.nix
        ./packages.nix
        ./shell.nix
        ./ssh.nix
      ];

      home = {
        username = "zekurio";
        homeDirectory = "/home/zekurio";
        stateVersion = "25.05";
        enableNixpkgsReleaseCheck = false;
      };
    };
  };
}
