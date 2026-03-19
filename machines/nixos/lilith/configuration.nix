{
  config,
  pkgs,
  modulesPath,
  ...
}: let
  serverPort = 7000;
  slskdPort = 50300;
  wgPort = 51820;
  wgAddress = "10.100.0.1/24";
  socksPort = 1080;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disko.nix
    ../default.nix
  ];

  # Boot configuration (disko handles grub device via EF02 partition)
  boot.loader.grub.enable = true;
  boot.initrd.availableKernelModules = ["ext4"];

  # Networking configuration
  networking = {
    hostName = "lilith";
    useDHCP = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        80
        443
        serverPort
        slskdPort
      ];
      allowedUDPPorts = [wgPort];
      interfaces.wg-adam.allowedTCPPorts = [socksPort];
    };

    # Point-to-point WireGuard tunnel to adam (homelab)
    # Allows adam's slskd to route Soulseek traffic through VPS via SOCKS5
    wireguard.interfaces.wg-adam = {
      ips = [wgAddress];
      listenPort = wgPort;
      privateKeyFile = config.sops.secrets.wg_private_key.path;
      peers = [
        {
          publicKey = "ujYESfLRaJuMc6rOI3REhq+9Fw8++voHe/fVzesuhnk=";
          allowedIPs = ["10.100.0.2/32"];
        }
      ];
    };
  };

  # SOPS secrets configuration
  sops = {
    defaultSopsFile = ../../../secrets/lilith.yaml;
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = false;
      sshKeyPaths = [];
    };
    gnupg.sshKeyPaths = [];
    secrets = {};
  };

  # FRP server
  services.frp = {
    enable = true;
    role = "server";
    settings = {
      bindPort = serverPort;
      auth = {
        method = "token";
        token = "{{ .Envs.FRP_TOKEN }}";
      };
    };
  };

  sops.secrets.frp_env = {
    mode = "0400";
  };

  systemd.services.frp.serviceConfig.EnvironmentFile = [config.sops.secrets.frp_env.path];

  sops.secrets.wg_private_key = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

  # Lightweight SOCKS5 proxy for slskd to route Soulseek connections through VPS
  systemd.services.microsocks = {
    description = "Lightweight SOCKS5 proxy (WireGuard only)";
    after = ["wireguard-wg-adam.service"];
    requires = ["wireguard-wg-adam.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = "${pkgs.microsocks}/bin/microsocks -i 10.100.0.1 -p ${toString socksPort}";
      DynamicUser = true;
      Restart = "always";
      RestartSec = 5;
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Accept SSH sessions coming from Ghostty, which sets TERM=xterm-ghostty.
  environment.systemPackages = [
    pkgs.ghostty.terminfo
  ];

  system.autoUpgrade = {
    enable = true;
    flake = "github:zekurio/nix#lilith";
    dates = "Sun *-*-* 03:00:00";
    randomizedDelaySec = "45min";
    allowReboot = true;
  };

  time.timeZone = "Europe/Vienna";

  # DO NOT TOUCH THIS
  system.stateVersion = "25.05";
}
