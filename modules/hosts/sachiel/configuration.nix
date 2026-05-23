{
  inputs,
  lib,
  pkgs,
  ...
}: let
  mainUser = "zekurio";
in {
  imports = [
    inputs.nixos-hardware.nixosModules.asus-zephyrus-ga401iv
  ];

  networking.hostName = "sachiel";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.loader = {
    efi.canTouchEfiVariables = true;
    systemd-boot.enable = lib.mkForce false;
  };

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  environment.systemPackages = [
    pkgs.sbctl
  ];

  boot.initrd.systemd = {
    enable = true;
    tpm2.enable = true;
  };

  # Hibernation resumes from the encrypted swap LV defined in ./disko.nix.
  powerManagement.enable = true;

  # nixos-hardware handles PRIME offload, modesetting, dynamic boost
  services.displayManager.plasma-login-manager.enable = true;
  services.desktopManager.plasma6.enable = true;

  fonts = {
    packages = with pkgs; [
      ibm-plex
      nerd-fonts.symbols-only
    ];

    fontconfig.defaultFonts = {
      sansSerif = [
        "IBM Plex Sans"
        "Symbols Nerd Font"
      ];
      monospace = [
        "IBM Plex Mono"
        "Symbols Nerd Font Mono"
      ];
    };
  };

  home-manager.users.${mainUser}.imports = [
    ../../home/zekurio/sachiel-desktop.nix
  ];

  system.stateVersion = "26.05";
}
