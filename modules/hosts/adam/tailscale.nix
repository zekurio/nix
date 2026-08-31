{
  flake.modules.nixos.adam = {config, ...}: {
    services.tailscale = {
      enable = true;
      authKeyFile = config.sops.secrets.tailscale_auth_key.path;
      extraUpFlags = [
        "--hostname=adam"
      ];
      # Clear the persisted exit-node advertisement as well as disabling the
      # forwarding support that was only needed while Adam provided it.
      extraSetFlags = ["--advertise-exit-node=false"];
      openFirewall = true;
      useRoutingFeatures = "none";
    };

    networking.firewall.interfaces.tailscale0 = {
      allowedTCPPorts = [2049];
    };
  };
}
