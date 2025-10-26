{ lib, pkgs, ... }:
{
  imports = [
    ./disko.nix
    ../../../modules/desktop
    ../../../modules/gaming
    ../../../modules/graphics
    ../../../modules/home-manager
    ../../../modules/users
    ../../../overlays
    ../default.nix
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
      "acpi_enforce_resources=lax"
      "amdgpu.ppfeaturemask=0xffffffff"
    ];
    kernelModules = [ "kvm-amd" "it87" ];
    extraModprobeConfig = ''
      options it87 force_id=0x8628
    '';
    kernelPackages = pkgs.linuxPackages_zen;
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
  };

  hardware = {
    enableRedistributableFirmware = true;
    bluetooth.enable = true;
    cpu.amd = {
      updateMicrocode = true;
      ryzen-smu.enable = true;
    };
  };

  modules.graphics.amd.enable = true;
  modules.desktop.hyprland.enable = true;
  modules.gaming.enable = true;

  modules.homeManager.bitwardenSsh.enable = true;
  modules.homeManager.dev.enable = true;
  modules.homeManager.dotfiles.enable = true;
  modules.homeManager.dotfiles.hyprland.enable = true;
  modules.homeManager.dotfiles.ghostty.enable = true;

  users.users.zekurio.extraGroups = lib.mkAfter [ "networkmanager" ];

  environment.systemPackages = lib.mkAfter [
    pkgs.sbctl
  ];

  programs.coolercontrol.enable = true;

  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  services.mullvad-vpn.enable = true;
  services.mullvad-vpn.package = pkgs.mullvad-vpn;
  services.power-profiles-daemon.enable = true;

  system.stateVersion = "25.05";
}
