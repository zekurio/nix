{
  flake.modules.nixos.adam = {config, ...}: {
    services.tailscale = {
      enable = true;
      authKeyFile = config.sops.secrets.tailscale_auth_key.path;
      extraUpFlags = [
        "--hostname=adam"
      ];
      openFirewall = true;
    };

    networking.firewall.interfaces.tailscale0 = {
      allowedTCPPorts = [2049];
    };
  };
}
