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
  wgPort = 51820;

  # Network IP parameters - can be overridden when importing this module
  networkIP = "192.168.0.2";
  tailscaleIP = "100.100.67.10";
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
  # Point-to-point WireGuard tunnel to lilith (VPS)
  # Used by slskd SOCKS5 proxy so the Soulseek server sees the VPS IP
  networking.wireguard.interfaces.wg-lilith = {
    ips = ["10.100.0.2/24"];
    listenPort = wgPort;
    privateKeyFile = config.sops.secrets.wg_private_key.path;
    peers = [
      {
        publicKey = "mw+8EknGkxgIdwGIWk58wws2Qi7jtl+WtzH3ndHuXgM=";
        allowedIPs = ["10.100.0.1/32"];
        endpoint = "46.224.128.128:51820";
        persistentKeepalive = 25;
      }
    ];
  };

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
    nameservers = ["127.0.0.1"];
    firewall.allowedUDPPorts = [
      53
      wgPort
    ];
    firewall.allowedTCPPorts = [2049]; # NFS
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  fileSystems."/mnt/downloads" = {
    device = "/dev/disk/by-uuid/b036ac8f-cb3c-468f-9a37-80351abe887c";
    fsType = "ext4";
    options = [
      "noatime"
      "nodiratime"
    ];
  };

  # SOPS secrets configuration
  sops = {
    defaultSopsFile = ../../../secrets/adam.yaml;
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = false;
      sshKeyPaths = [];
    };
    gnupg.sshKeyPaths = [];
    secrets = {
      wg_private_key = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };
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

    # Tailscale VPN
    tailscale = {
      enable = true;
      useRoutingFeatures = "server";
      openFirewall = true;
    };

    # Samba network shares for ZFS tank pool
    samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          workgroup = "WORKGROUP";
          "server string" = "adam";
          "netbios name" = "adam";
          security = "user";
          "hosts allow" = "192.168.0.0/24 100.64.0.0/10 127.0.0.1 localhost";
          "hosts deny" = "0.0.0.0/0";
          "guest account" = "nobody";
          "map to guest" = "Bad User";
          "server min protocol" = "SMB2";
          "socket options" = "TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072";
          "use sendfile" = "yes";
          "aio read size" = "16384";
          "aio write size" = "16384";
        };
        media = {
          path = "/tank/media";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "valid users" = "@${shareGroup}";
          "force user" = shareUser;
          "force group" = shareGroup;
          "create mask" = "0664";
          "directory mask" = "2775";
          comment = "Media Library";
        };
        vault = {
          path = "/tank/vault";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "valid users" = mainUser;
          "force user" = mainUser;
          "force group" = mainUser;
          "create mask" = "0664";
          "directory mask" = "0755";
          comment = "Vault";
        };
        datadrop = {
          path = "/mnt/downloads";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "valid users" = "@${shareGroup}";
          "force user" = shareUser;
          "force group" = shareGroup;
          "create mask" = "0664";
          "directory mask" = "2775";
          comment = "Downloads";
        };
      };
    };

    # Enable SMB autodiscovery
    samba-wsdd = {
      enable = true;
      openFirewall = true;
    };

    # NFS server
    nfs.server = {
      enable = true;
      exports = ''
        /tank/vault    192.168.0.0/24(rw,sync,no_subtree_check,no_root_squash) 100.64.0.0/10(rw,sync,no_subtree_check,no_root_squash)
        /tank/media    192.168.0.0/24(rw,sync,no_subtree_check,no_root_squash) 100.64.0.0/10(rw,sync,no_subtree_check,no_root_squash)
        /mnt/downloads 192.168.0.0/24(rw,sync,no_subtree_check,no_root_squash) 100.64.0.0/10(rw,sync,no_subtree_check,no_root_squash)
      '';
    };

    # Unbound DNS server
    unbound = {
      enable = true;
      settings = {
        server = {
          interface = [
            "127.0.0.1"
            "::1"
            "0.0.0.0"
          ];
          access-control = [
            "127.0.0.0/8 allow"
            "::1/128 allow"
            "192.168.0.0/16 allow"
            "100.64.0.0/10 allow"
          ];
          access-control-view = [
            "192.168.0.0/16 lan"
            "100.64.0.0/10 tailscale"
          ];
          do-ip4 = "yes";
          do-ip6 = "yes";
          do-udp = "yes";
          do-tcp = "yes";
          hide-identity = "yes";
          hide-version = "yes";
          harden-glue = "yes";
          harden-dnssec-stripped = "yes";
          use-caps-for-id = "yes";
          prefetch = "yes";
          prefetch-key = "yes";
          qname-minimisation = "yes";
          rrset-roundrobin = "yes";
          minimal-responses = "yes";
          cache-min-ttl = 300;
          cache-max-ttl = 86400;
        };

        forward-zone = {
          name = ".";
          forward-ssl-upstream = "yes";
          forward-addr = [
            "9.9.9.9@853#dns.quad9.net"
            "149.112.112.112@853#dns.quad9.net"
          ];
        };

        view = [
          {
            name = "lan";
            local-zone = [
              "schnitzelflix.xyz. transparent"
              "zekurio.xyz. transparent"
            ];
            local-data = [
              "\"adam.local. 3600 IN A ${networkIP}\""
              "\"schnitzelflix.xyz. 3600 IN A ${networkIP}\""
              "\"requests.schnitzelflix.xyz. 3600 IN A ${networkIP}\""
              "\"sab.schnitzelflix.xyz. 3600 IN A ${networkIP}\""
              "\"arr.schnitzelflix.xyz. 3600 IN A ${networkIP}\""
              "\"ff.schnitzelflix.xyz. 3600 IN A ${networkIP}\""
              "\"jt.schnitzelflix.xyz. 3600 IN A ${networkIP}\""
              "\"stats.schnitzelflix.xyz. 3600 IN A ${networkIP}\""
              "\"photos.zekurio.xyz. 3600 IN A ${networkIP}\""
              "\"auth.zekurio.xyz. 3600 IN A ${networkIP}\""
              "\"slskd.zekurio.xyz. 3600 IN A ${networkIP}\""
            ];
          }
          {
            name = "tailscale";
            local-zone = [
              "schnitzelflix.xyz. transparent"
              "zekurio.xyz. transparent"
            ];
            local-data = [
              "\"adam.local. 3600 IN A ${tailscaleIP}\""
              "\"schnitzelflix.xyz. 3600 IN A ${tailscaleIP}\""
              "\"requests.schnitzelflix.xyz. 3600 IN A ${tailscaleIP}\""
              "\"sab.schnitzelflix.xyz. 3600 IN A ${tailscaleIP}\""
              "\"arr.schnitzelflix.xyz. 3600 IN A ${tailscaleIP}\""
              "\"ff.schnitzelflix.xyz. 3600 IN A ${tailscaleIP}\""
              "\"jt.schnitzelflix.xyz. 3600 IN A ${tailscaleIP}\""
              "\"stats.schnitzelflix.xyz. 3600 IN A ${tailscaleIP}\""
              "\"zekurio.xyz. 3600 IN A ${tailscaleIP}\""
              "\"photos.zekurio.xyz. 3600 IN A ${tailscaleIP}\""
              "\"auth.zekurio.xyz. 3600 IN A ${tailscaleIP}\""
              "\"slskd.zekurio.xyz. 3600 IN A ${tailscaleIP}\""
            ];
          }
        ];
      };
    };
  };

  services.homelab = {
    beets.enable = true;
    configarr.enable = true;
    frp.enable = true;
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
