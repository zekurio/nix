{
  config,
  inputs,
  pkgs,
  modulesPath,
  ...
}: let
  mainUser = "zekurio";
  shareUser = "share";
  shareGroup = "share";
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
  ];

  home-manager.users.${mainUser}.profiles.dev.enable = false;

  # Boot configuration
  boot = {
    kernelParams = [
      "pcie_aspm=force"
      "pcie_aspm.policy=powersave"
      "consoleblank=60"
      "i915.enable_guc=3"
    ];
    kernelModules = [
      "kvm-amd"
      "zenpower"
    ];
    extraModulePackages = [config.boot.kernelPackages.zenpower];
    blacklistedKernelModules = ["k10temp"];
    loader = {
      timeout = 0;
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    supportedFilesystems = ["zfs"];
    zfs.extraPools = ["tank"];
  };

  # Hardware configuration
  hardware = {
    enableRedistributableFirmware = true;
    firmware = [pkgs.linux-firmware];
    cpu.amd = {
      updateMicrocode = true;
      ryzen-smu.enable = true;
    };
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-compute-runtime
        vpl-gpu-rt
        nvtopPackages.intel
      ];
    };
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  modules.virtualization.enable = true;

  modules.homelab.mediaShare = {
    enable = true;
    collaborators = [mainUser];
  };

  # Networking configuration
  networking = {
    hostName = "adam";
    useDHCP = true;
    networkmanager.enable = false;
    firewall.enable = true;
    hostId = "eab7e93e"; # nix run nixpkgs#openssl -- rand -hex 4
    # Keep upstream resolvers DHCP-driven, but make Adam's own public service
    # domains resolve locally so self-referential traffic does not depend on
    # public DNS or router hairpin support.
    hosts = {
      "127.0.0.1" = [
        "adam.lan"
        "schnitzelflix.xyz"
        "requests.schnitzelflix.xyz"
        "sab.schnitzelflix.xyz"
        "arr.schnitzelflix.xyz"
        "trace.schnitzelflix.xyz"
        "accounts.schnitzelflix.xyz"
        "auth.zekurio.xyz"
        "photos.zekurio.xyz"
        "docs.zekurio.xyz"
        "slskd.zekurio.xyz"
      ];
      "::1" = [
        "adam.lan"
        "schnitzelflix.xyz"
        "requests.schnitzelflix.xyz"
        "sab.schnitzelflix.xyz"
        "arr.schnitzelflix.xyz"
        "trace.schnitzelflix.xyz"
        "accounts.schnitzelflix.xyz"
        "auth.zekurio.xyz"
        "photos.zekurio.xyz"
        "docs.zekurio.xyz"
        "slskd.zekurio.xyz"
      ];
    };
    firewall.allowedTCPPorts = [2049]; # NFS
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  # SOPS secrets configuration
  sops = {
    defaultSopsFile = ../../../secrets/adam.yaml;
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = false;
      sshKeyPaths = [];
    };
    gnupg.sshKeyPaths = [];
    secrets = {};
  };

  # System packages
  environment.systemPackages = with pkgs; [
    ryzen-monitor-ng
    zfs
    lm_sensors
    intel-gpu-tools
    lsof
  ];

  services = {
    autoaspm.enable = true;

    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };

  services.homelab = {
    beets.enable = true;
    configarr.enable = true;
    immich.enable = true;
    jellyfin.enable = true;
    jellything.enable = true;
    oauth2-proxy.enable = true;
    paperless-ngx.enable = true;
    pocket-id.enable = true;
    prowlarr.enable = true;
    radarr.enable = true;
    sabnzbd.enable = true;
    seerr.enable = true;
    slskd.enable = true;
    sonarr.enable = true;
    tracearr.enable = true;
  };

  system.autoUpgrade = {
    enable = true;
    flake = "github:zekurio/nix#adam";
    dates = "Sun *-*-* 03:00:00";
    randomizedDelaySec = "45min";
    allowReboot = true;
  };

  time.timeZone = "Europe/Vienna";

  # DO NOT TOUCH THIS
  system.stateVersion = "25.05";
}
