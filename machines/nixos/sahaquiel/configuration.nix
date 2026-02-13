{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
    ../default.nix
  ];

  boot.loader = {
    timeout = 3;
    grub.enable = true;
  };

  boot.initrd.availableKernelModules = [
    "ahci"
    "sd_mod"
    "sr_mod"
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
  ];

  fileSystems."/".device = lib.mkForce "/dev/sda2";

  networking = {
    hostName = "sahaquiel";
    useDHCP = true;
    networkmanager.enable = false;
    nftables.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
        80
        443
      ];
      allowedUDPPorts = [
        443
        51820
        21820
      ];
    };
  };

  modules.virtualization.enable = true;

  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };

  system.autoUpgrade = {
    enable = true;
    flake = "github:zekurio/nix#sahaquiel";
    dates = "daily";
    randomizedDelaySec = "45min";
    allowReboot = true;
  };

  time.timeZone = "Europe/Vienna";

  home-manager.users.zekurio.modules.hm = {
    shell.enable = lib.mkForce true;
    desktop.enable = lib.mkForce false;
  };

  system.stateVersion = "25.11";
}
