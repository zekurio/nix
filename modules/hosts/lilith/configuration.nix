{...}: {
  flake.modules.nixos.lilith = {
    modulesPath,
    pkgs,
    ...
  }: {
    imports = [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

    nixpkgs.hostPlatform = "x86_64-linux";

    networking = {
      hostName = "lilith";
      firewall.enable = true;
      networkmanager = {
        enable = true;
        dns = "systemd-resolved";
      };
    };

    services = {
      resolved.enable = true;
      printing.enable = true;
      fwupd.enable = true;
      tailscale = {
        enable = true;
        # UDP 41641 inbound lets peers connect directly instead of falling
        # back to DERP relays.
        openFirewall = true;
        # Linux rejects advertised subnet routes by default. Flint provides
        # both the 10.0.0.0/24 route and tailnet DNS.
        useRoutingFeatures = "client";
        extraSetFlags = [
          "--accept-dns=true"
          "--accept-routes=true"
          "--hostname=lilith"
        ];
      };
      mullvad-vpn.enable = true;
    };

    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    users.users.zekurio.extraGroups = [
      "gamemode"
      "networkmanager"
    ];

    environment.systemPackages = with pkgs; [
      mullvad-vpn
      tailscale-systray
    ];

    # DO NOT TOUCH THIS
    system.stateVersion = "26.05";
  };
}
