{...}: let
  sharePath = "/tank/shares/zekurio";
  clientPath = "/home/zekurio/Share";
  serverAddress = "10.0.0.2";
  lanCidr = "10.0.0.0/24";
in {
  flake.modules.nixos = {
    adam = {
      config,
      lib,
      ...
    }: let
      userId = config.users.users.zekurio.uid;
      groupId = config.users.groups.zekurio.gid;
    in {
      # Export the complete private share instead of maintaining a second,
      # Immich-specific view of one of its directories. Squashing all clients
      # to zekurio preserves the share's private 0700 ownership model.
      services.nfs.server.exports = lib.mkAfter ''
        /tank ${lanCidr}(ro,fsid=0,no_subtree_check)
        /tank/shares ${lanCidr}(ro,no_subtree_check)
        ${sharePath} ${lanCidr}(rw,sync,no_subtree_check,nohide,all_squash,anonuid=${toString userId},anongid=${toString groupId},insecure)
      '';

      networking.firewall.interfaces.enp42s0.allowedTCPPorts = [2049];
    };

    lilith = {lib, ...}: {
      # Keep the network share visible at a stable, top-level home directory
      # without delaying boot when adam is unavailable.
      fileSystems.${clientPath} = {
        # The router does not publish adam in DNS, but its LAN address is fixed.
        device = "${serverAddress}:${lib.removePrefix "/tank" sharePath}";
        fsType = "nfs";
        options = [
          "nfsvers=4.2"
          "rw"
          "_netdev"
          "noauto"
          "nofail"
          "x-systemd.automount"
          "x-systemd.idle-timeout=10min"
          "x-systemd.mount-timeout=10s"
        ];
      };
    };
  };
}
