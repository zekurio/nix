{
  config,
  modulesPath,
  ...
}:
let
  serverPort = 7000;
  slskdPort = 50300;
in
{
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
    hostName = "shamshel";
    useDHCP = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        80
        443
        serverPort
        slskdPort
      ];
    };
  };

  # SOPS secrets configuration
  sops = {
    defaultSopsFile = ../../../secrets/shamshel.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
    secrets = { };
  };

  # FRP server
  services.frp.instances.default = {
    enable = true;
    role = "server";
    environmentFiles = [config.sops.secrets.frp_env.path];
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

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  system.autoUpgrade = {
    enable = true;
    flake = "github:zekurio/nix#shamshel";
    dates = "daily";
    randomizedDelaySec = "45min";
    allowReboot = true;
  };

  time.timeZone = "Europe/Vienna";

  # DO NOT TOUCH THIS
  system.stateVersion = "25.05";
}
