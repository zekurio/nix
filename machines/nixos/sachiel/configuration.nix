{ lib, pkgs, ... }: {
  imports = [
    ../default.nix
    ./disko.nix
    ../../../modules/desktop
    ../../../modules/gaming
    ../../../modules/graphics
    ../../../modules/virtualization
  ];

  services.resolved = {
    enable = true;
    dnssec = "true";
    domains = [ "~." ];
    fallbackDns = [ "1.1.1.1#one.one.one.one" "1.0.0.1#one.one.one.one" ];
    dnsovertls = "true";
  };

  networking.hostName = "sachiel";
  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "systemd-resolved";
  networking.nameservers = [ "1.1.1.1#one.one.one.one" "1.0.0.1#one.one.one.one" ];

  time.timeZone = lib.mkDefault "Europe/Vienna";

  boot = {
    loader = {
      timeout = 0;
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    initrd = {
      verbose = false;
      systemd = {
        enable = true;
        tpm2.enable = true;
      };
      luks.devices = {
        cryptroot = {
          device = "/dev/disk/by-partlabel/root";
          allowDiscards = true;
          bypassWorkqueues = true;
        };
      };
    };
    kernelParams = [
      "quiet"
      "splash"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "boot.shell_on_fail"
    ];
    kernelModules = [ "kvm-amd" "zenpower" ];
    extraModulePackages = [ pkgs.linuxPackages_zen.zenpower ];
    blacklistedKernelModules = [ "k10temp" ];
    kernelPackages = pkgs.linuxPackages_zen;
    # lanzaboote = {
    #   enable = true;
    #   pkiBundle = "/var/lib/sbctl";
    # };
  };

  hardware = {
    enableRedistributableFirmware = true;
    bluetooth.enable = true;
    cpu.amd = {
      updateMicrocode = true;
      ryzen-smu.enable = true;
    };
  };

  modules = {
    desktop.hyprland = {
      enable = true;
      monitors = [
        "eDP-1,1920x1080@120,0x0,auto,vrr,1"
      ];
      input = {
        kb_layout = "de";
        accel_profile = "adaptive";
        touchpad.scroll_factor = 0.2;
      };
    };
    gaming.enable = true;
    graphics.amd-nvidia.enable = true;
    homeManager = {
      bitwardenSsh.enable = true;

    };
    virtualization.enable = true;
  };

  security.tpm2.enable = true;

  systemd.tpm2.enable = true;

  users.users.zekurio.extraGroups = lib.mkAfter [ "networkmanager" ];

  environment.systemPackages = lib.mkAfter [
    pkgs.sbctl
    pkgs.cryptsetup
  ];

  services = {
    fwupd.enable = true;
    gvfs.enable = true;
    mullvad-vpn = {
      enable = true;
      package = pkgs.mullvad-vpn;
    };
    openssh = {
      enable = lib.mkDefault true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    power-profiles-daemon.enable = true;
  };

  system.stateVersion = "25.05";
}
