{
  flake.modules.nixos.adam = {config, ...}: {
    networking = {
      hostName = "adam";
      useDHCP = false;
      networkmanager.enable = false;
      firewall.enable = true;
      hosts = {
        # The auth name must resolve to adam's LAN address, not loopback:
        # systemd-resolved hands /etc/hosts entries to containers, where
        # 127.0.0.1 is the container itself, and Fluxer's SSO validation
        # rejects loopback issuers outright.
        "10.0.0.2" = ["auth.${config.services.homelab.domains.zekurio}"];
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
        matchConfig.Name = "podman0 fluxer0 veth*";
        networkConfig.DHCP = "no";
        linkConfig.Unmanaged = true;
      };
    };
  };
}
