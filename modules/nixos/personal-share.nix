{...}: let
  sharePath = "/tank/shares/zekurio";
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
  };
}
