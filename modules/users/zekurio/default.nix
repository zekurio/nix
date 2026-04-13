{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cliPackages = with pkgs; [
    age
    bat
    btop
    eza
    envsubst
    gh
    git
    jq
    ripgrep
    sops
    zellij
  ];

  desktopPackages = let
    t3codePackages = inputs.t3code.packages.${pkgs.stdenv.hostPlatform.system};
  in [
    pkgs.kdePackages.ark
    pkgs.brave
    pkgs.feishin
    pkgs.haruna
    pkgs.jellyfin-desktop
    pkgs.kdePackages.dolphin
    pkgs.kdePackages.gwenview
    pkgs.kdePackages.konsole
    pkgs.kdePackages.okular
    pkgs.kdePackages.partitionmanager
    pkgs.kdePackages.spectacle
    pkgs.kitty
    pkgs.klassy
    pkgs.kdePackages.qtstyleplugin-kvantum
    pkgs.vesktop
    pkgs.zed-editor
    t3codePackages.default
  ];

  devPackages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
    pkgs.nil
    pkgs.nixd
    pkgs.uv
  ];
in {
  nix.settings.trusted-users = ["zekurio"];

  programs.vim = {
    enable = true;
    defaultEditor = true;
  };

  programs.fish.enable = true;

  environment.shells = [pkgs.fish];
  environment.systemPackages =
    lib.optionals config.home-manager.users.zekurio.profiles.packages.cli.enable cliPackages
    ++ lib.optionals config.home-manager.users.zekurio.profiles.desktop.enable desktopPackages
    ++ lib.optionals config.home-manager.users.zekurio.profiles.dev.enable devPackages;

  users = {
    defaultUserShell = pkgs.fish;

    users.zekurio = {
      shell = pkgs.fish;
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
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOXuY93/KsNdn9B9LW4JwPGpHa5d5W0XHYttP5wdHDb8 zekurio"
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
