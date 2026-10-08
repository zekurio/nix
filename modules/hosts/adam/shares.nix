{
  flake.modules.nixos.adam = {config, ...}: {
    sops.secrets.smb_password_zekurio = {};

    services.homelab.mediaShare = {
      enable = true;
      collaborators = ["zekurio"];
      nfs.enable = true;
      samba = {
        enable = true;
        interfaces = [
          "enp42s0"
          "tailscale0"
        ];
        discovery = {
          enable = true;
          interfaces = ["enp42s0"];
        };
        passwordFiles.zekurio = config.sops.secrets.smb_password_zekurio.path;
      };
      userShares.zekurio.quota = "50G";
    };
  };
}
