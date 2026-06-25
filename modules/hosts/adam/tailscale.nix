{config, ...}: {
  services.tailscale = {
    enable = true;
    authKeyFile = config.sops.secrets.tailscale_auth_key.path;
    extraUpFlags = [
      "--hostname=adam"
    ];
    openFirewall = true;
  };

  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [
      139
      445
      2049
    ];
    allowedUDPPorts = [
      137
      138
    ];
  };
}
