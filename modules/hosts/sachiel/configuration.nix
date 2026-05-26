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

  boot.kernelParams = [
    "mem_sleep_default=deep"
    "pcie_aspm.policy=powersupersave"
  ];

  boot.loader = {
    efi.canTouchEfiVariables = true;
    systemd-boot.enable = lib.mkForce false;
  };

  boot.lanzaboote = {
    enable = true;
    configurationLimit = 3;
    pkiBundle = "/var/lib/sbctl";
  };

  environment.systemPackages = [
    pkgs.powertop
    pkgs.sbctl
  ];

  boot.initrd.systemd = {
    enable = true;
    tpm2.enable = true;
  };

  # Hibernation resumes from the encrypted swap LV defined in ./disko.nix.
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "schedutil";
    powertop = {
      enable = true;
      postStart = ''
        # Keep the internal ASUS keyboard responsive after powertop enables
        # autosuspend globally.
        for device in /sys/bus/usb/devices/*; do
          if [ -f "$device/idVendor" ] \
            && [ -f "$device/idProduct" ] \
            && [ "$(cat "$device/idVendor")" = "0b05" ] \
            && [ "$(cat "$device/idProduct")" = "1866" ] \
            && [ -w "$device/power/control" ]; then
            echo on > "$device/power/control"
          fi
        done
      '';
    };
  };

  # Keep PRIME render offload available, but allow the NVIDIA GPU to enter
  # runtime D3 when the hardware/driver combination supports it.
  hardware.nvidia = {
    powerManagement = {
      enable = true;
      finegrained = true;
    };
  };

  specialisation."igpu-only".configuration = {
    system.nixos.tags = ["igpu-only"];
    imports = [
      "${inputs.nixos-hardware}/common/gpu/nvidia/disable.nix"
    ];
    hardware.nvidia = {
      prime.offload.enable = lib.mkForce false;
      powerManagement = {
        enable = lib.mkForce false;
        finegrained = lib.mkForce false;
      };
    };
  };

  services.tuned = {
    enable = true;
    ppdSupport = true;
    ppdSettings = {
      main.default = "power-saver";
      profiles = {
        power-saver = "powersave";
        balanced = "balanced-battery";
        performance = "balanced";
      };
      battery = {
        balanced = "balanced-battery";
      };
    };
  };

  # nixos-hardware's generic laptop module defaults TLP on when the original
  # power-profiles-daemon is off. Force it off so TuneD owns power policy.
  services.tlp.enable = lib.mkForce false;
  services.autoaspm.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  # nixos-hardware handles PRIME offload, modesetting, dynamic boost

  home-manager.users.${mainUser}.imports = [
    ../../home/zekurio/hosts/sachiel-desktop.nix
  ];

  system.stateVersion = "26.05";
}
