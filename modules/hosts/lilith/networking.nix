{
  networking = {
    hostName = "lilith";
    firewall.enable = true;
    useDHCP = false;
    useNetworkd = true;
    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
      unmanaged = ["interface-name:eno1"];
    };
  };

  # NetworkManager drops routes when logind announces sleep, before the
  # kernel syncs the hard NFS mount. networkd keeps eno1 configured through
  # that sync; the kernel suspends the NIC afterwards. NM still owns Wi-Fi.
  systemd.network = {
    enable = true;
    networks."10-lan" = {
      matchConfig.Name = "eno1";
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = true;
      };
      # Preserve the MAC-based identity used for the router's DHCP lease.
      dhcpV4Config.ClientIdentifier = "mac";
    };
  };

  services.resolved.enable = true;

  users.users.zekurio.extraGroups = ["networkmanager"];
}
