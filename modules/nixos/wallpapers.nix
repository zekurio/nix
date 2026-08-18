{...}: let
  # Keep the exported source and client mount together: applications persist
  # absolute paths into this library, so changing either side requires a
  # coordinated update.
  serverPath = "/tank/shares/zekurio/Immich External Library";
  clientPath = "/home/zekurio/Pictures/Immich";
  lanCidr = "10.0.0.0/24";
in {
  flake.modules.nixos = {
    adam = {lib, ...}: {
      # NFSv4 clients first enter the pseudo-root and can then traverse only
      # explicitly exported child filesystems. Do not use crossmnt here: that
      # would expose unrelated datasets below /tank to the home LAN.
      services.nfs.server.exports = lib.mkAfter ''
        /tank ${lanCidr}(ro,fsid=0,no_subtree_check)
        ${builtins.replaceStrings [" "] ["\\040"] serverPath} ${lanCidr}(ro,sync,no_subtree_check)
      '';

      networking.firewall.interfaces.enp42s0.allowedTCPPorts = [2049];
    };

    lilith = {lib, ...}: {
      fileSystems.${clientPath} = {
        device = "adam:${lib.removePrefix "/tank" serverPath}";
        fsType = "nfs";
        options = [
          "nfsvers=4.2"
          "ro"
          "_netdev"
          "noauto"
          "nofail"
          "x-systemd.automount"
          "x-systemd.device-timeout=5s"
          "x-systemd.idle-timeout=10min"
          "x-systemd.mount-timeout=10s"
        ];
      };
    };
  };
}
