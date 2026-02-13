{
  config,
  lib,
  modulesPath,
  ...
}:
{
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
      allowedTCPPorts = [ 22 ];
    };
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    pangolin = {
      enable = true;
      openFirewall = true;
      baseDomain = "zekurio.xyz";
      dashboardDomain = "edge.zekurio.xyz";
      dnsProvider = "cloudflare";
      letsEncryptEmail = "git@zekurio.xyz";
      environmentFile = config.sops.secrets.pangolin_env.path;
      settings = {
        app.telemetry.anonymous_usage = false;
        flags = {
          disable_signup_without_invite = true;
          disable_user_create_org = true;
          require_email_verification = false;
        };
      };
    };

    crowdsec = {
      enable = true;
      settings = {
        general.api.server.enable = true;
        lapi.credentialsFile = "/etc/crowdsec/local_api_credentials.yaml";
      };
      hub.collections = [
        "crowdsecurity/linux"
        "crowdsecurity/sshd"
      ];
      localConfig.acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
          labels.type = "syslog";
        }
      ];
    };

    crowdsec-firewall-bouncer = {
      enable = true;
      settings = {
        mode = "nftables";
        update_frequency = "10s";
      };
    };
  };

  sops = {
    defaultSopsFile = ../../../secrets/sahaquiel.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
    secrets = {
      pangolin_env = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };
  };

  time.timeZone = "Europe/Vienna";

  home-manager.users.zekurio.modules.hm = {
    shell.enable = lib.mkForce true;
    desktop.enable = lib.mkForce false;
  };

  system.stateVersion = "25.11";
}
