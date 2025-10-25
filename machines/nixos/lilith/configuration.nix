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
      systemd-boot.enable = true;
    };
    initrd = {
      verbose = false;
    };
    kernelParams = [
      "quiet"
      "splash"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "boot.shell_on_fail"
    ];
    kernelModules = [ "kvm-amd" ];
    kernelPackages = pkgs.linuxPackages_zen;
  };

  hardware = {
    enableRedistributableFirmware = true;
    bluetooth.enable = true;
    cpu.amd = {
      updateMicrocode = true;
      ryzen-smu.enable = true;
    };
    xone.enable = true;
  };

  modules.graphics.amd.enable = true;
  modules.desktop.hyprland.enable = true;

  modules.homeManager.dotfiles.enable = true;
  modules.homeManager.dotfiles.hyprland.enable = true;
  modules.homeManager.dotfiles.ghostty.enable = true;

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
