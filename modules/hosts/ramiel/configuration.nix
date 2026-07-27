{inputs, ...}: {
  flake.modules.nixos.ramiel = {modulesPath, ...}: {
    imports = [
      (modulesPath + "/profiles/qemu-guest.nix")
      inputs.disko.nixosModules.disko
      inputs.sops-nix.nixosModules.sops
    ];

    nixpkgs.hostPlatform = "x86_64-linux";

    # Hetzner Cloud VMs boot legacy BIOS (SeaBIOS). No explicit GRUB config
    # here: disko sees the EF02 BIOS boot partition in disko.nix and points
    # boot.loader.grub.devices at /dev/sda itself.

    networking = {
      hostName = "ramiel";
      # Hetzner Cloud hands out the IPv4 via DHCP (point-to-point /32). IPv6 is
      # deliberately left unconfigured: the /64 needs static setup and nothing
      # here requires it yet.
      useDHCP = true;
      firewall = {
        enable = true;
        # 22 comes from modules.ssh; 51820/21820 UDP are Gerbil/WireGuard.
        allowedTCPPorts = [
          80
          443
        ];
        allowedUDPPorts = [
          51820
          21820
        ];
      };
    };

    # Public edge host: sshd is internet-facing, so brute-force throttling is
    # worth it here (unlike adam, where SSH is LAN/Tailscale only).
    services.fail2ban = {
      enable = true;
      maxretry = 5;
      bantime = "1h";
      bantime-increment.enable = true;
    };

    services.qemuGuest.enable = true;

    # Pull model like adam, but calmer: monthly, matching the stable channel.
    system.autoUpgrade = {
      enable = true;
      flake = "github:zekurio/nix#ramiel";
      dates = "*-*-01 04:00:00";
      randomizedDelaySec = "45min";
      allowReboot = true;
    };

    # SOPS secrets for this host live in secrets/ramiel.yaml, keyed by the
    # host's own SSH key (derived automatically by sops-nix).
    sops = {
      defaultSopsFile = ../../../secrets/ramiel.yaml;
      # Default age.sshKeyPaths already covers /etc/ssh/ssh_host_ed25519_key.
      gnupg.sshKeyPaths = [];
    };

    system.stateVersion = "26.05";
  };
}
