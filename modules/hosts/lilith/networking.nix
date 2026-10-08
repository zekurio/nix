{
  flake.modules.nixos.lilith = {
    networking = {
      hostName = "lilith";
      firewall.enable = true;
      networkmanager = {
        enable = true;
        dns = "systemd-resolved";
      };
    };

    services.resolved.enable = true;

    users.users.zekurio.extraGroups = ["networkmanager"];
  };
}
