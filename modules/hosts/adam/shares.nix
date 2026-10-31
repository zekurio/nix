{config, ...}: {
  # samba-passwd sets the account password once per start, so a rotated
  # password needs it to run again.
  sops.secrets.smb_password_zekurio.restartUnits = ["samba-passwd.service"];

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
}
