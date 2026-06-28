{
  config,
  pkgs,
  modulesPath,
  ...
}: let
  mainUser = "zekurio";
  mainUserHome = "/home/${mainUser}";
  mainUserSshKey = "${mainUserHome}/.ssh/id_ed25519";
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
    ./tailscale.nix
    ./zfs.nix
  ];

  # Boot configuration
  boot = {
    kernelParams = [
      "amd_pstate=guided"
      "microcode.amd_sha_check=off"
      "pcie_aspm=force"
      "pcie_aspm.policy=powersave"
      "consoleblank=60"
      "i915.enable_guc=3"
      "acpi_enforce_resources=lax"
    ];
    kernelModules = [
      "kvm-amd"
      "zenpower"
      "nct6687"
    ];
    extraModprobeConfig = ''
      softdep nct6687 pre: i2c_i801
      options nct6687
    '';
    extraModulePackages = [
      config.boot.kernelPackages.zenpower
      (config.boot.kernelPackages.callPackage ./nct6687d.nix {})
    ];
    blacklistedKernelModules = [
      "k10temp"
      "nct6683"
    ];
    loader = {
      timeout = 0;
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    supportedFilesystems = ["zfs"];
    zfs = {
      extraPools = ["tank"];
      forceImportRoot = false;
    };
  };

  # Hardware configuration
  hardware = {
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

  powerManagement.cpuFreqGovernor = "schedutil";

  services.ucodenix.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      AllowAgentForwarding = true;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  home-manager.users.${mainUser} = {
    programs.keychain = {
      enable = true;
      enableFishIntegration = true;
      keys = [mainUserSshKey];
    };

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings."github.com" = {
        IdentityFile = mainUserSshKey;
        IdentitiesOnly = true;
        AddKeysToAgent = "yes";
      };
    };

    programs.git.settings.user = {
      signingkey = mainUserSshKey;
    };
  };

  modules.virtualization.enable = true;

  modules.homelab.mediaShare = {
    enable = true;
    collaborators = [mainUser];
    nfs.enable = true;
    samba.enable = true;
  };

  # Networking configuration
  networking = {
    hostName = "adam";
    useDHCP = false;
    networkmanager.enable = false;
    firewall.enable = true;
    hostId = "eab7e93e";
    hosts = {
      "127.0.0.1" = ["auth.zekurio.me"];
    };
    useNetworkd = true;
  };

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = ["10.0.0.1"];
      DNSSEC = false;
      Domains = ["~."];
      FallbackDNS = [];
      DNSStubListener = true;
    };
  };

  systemd.network = {
    enable = true;
    networks."10-lan" = {
      matchConfig.Name = "enp42s0";
      networkConfig = {
        DHCP = "yes";
        DNS = "10.0.0.1";
      };
      dhcpV4Config = {
        UseDNS = false;
        UseNTP = true;
      };
    };
    networks."99-podman" = {
      matchConfig.Name = "podman0 veth*";
      networkConfig.DHCP = "no";
      linkConfig.Unmanaged = true;
    };
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
    secrets.tailscale_auth_key = {};
  };

  # System packages
  environment.systemPackages = with pkgs; [
    kitty.terminfo
    ryzen-monitor-ng
    zfs
    lm_sensors
    intel-gpu-tools
    lsof
  ];

  services.autoaspm.enable = true;

  services.homelab = {
    alloy.enable = true;
    anvil.enable = true;
    beets.enable = true;
    blitzcrank.enable = true;
    coolercontrol = {
      enable = true;
      listenAddress = "0.0.0.0";
      listenAddress6 = "::";
      allowedInterfaces = ["enp42s0"];
    };
    immich.enable = true;
    jellyfin.enable = true;
    navidrome.enable = true;
    oauth2-proxy.enable = true;
    paperless-ngx.enable = true;
    pocket-id.enable = true;
    prowlarr.enable = true;
    qbittorrent.enable = true;
    radarr.enable = true;
    sabnzbd.enable = true;
    seerr.enable = true;
    slskd.enable = true;
    sonarr.enable = true;
    vaultwarden.enable = true;
    windrose = {
      enable = false;
      maxPlayers = 4;
      hostNetwork = true;
      p2pProxyAddress = "10.0.0.2";
    };
  };

  system.autoUpgrade = {
    enable = true;
    flake = "github:zekurio/nix#adam";
    dates = "Sun *-*-* 03:00:00";
    randomizedDelaySec = "45min";
    allowReboot = true;
  };

  # DO NOT TOUCH THIS
  system.stateVersion = "25.05";
}
