{
  flake.modules.nixos.adam = {config, ...}: {
    services.tailscale = {
      enable = true;
      authKeyFile = config.sops.secrets.tailscale_auth_key.path;
      extraUpFlags = [
        "--hostname=adam"
      ];
      # T3 Code manages its tailnet-only HTTPS proxy through `tailscale serve`
      # while running as this unprivileged user.
      extraSetFlags = ["--operator=zekurio"];
      openFirewall = true;
    };

    networking.firewall.interfaces.tailscale0 = {
      allowedTCPPorts = [2049];
    };
  };
}
