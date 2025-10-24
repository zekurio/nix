{ lib, pkgs, ... }:
{
  imports = [
    ./disko.nix
    ../../../modules/graphics
    ../../../modules/home-manager
    ../../../modules/desktop
    ../../../overlays
  ];

  networking = {
    hostName = "lilith";
    useDHCP = lib.mkDefault true;
    networkmanager.enable = true;
  };

  time.timeZone = lib.mkDefault "Europe/Vienna";

  boot = {
    loader = {
      timeout = 0;
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = lib.mkForce false;
    };
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
  };

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;
  };

  modules.graphics.amd.enable = true;
  modules.desktop.hyprland.enable = true;

  users.users.zekurio.extraGroups = lib.mkAfter [ "networkmanager" ];

  environment.systemPackages = lib.mkAfter [
    pkgs.sbctl
  ];

  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  system.stateVersion = "25.05";
}
