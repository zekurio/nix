{
  config,
  lib,
  ...
}: let
  cfg = config.modules.ssh;
in {
  options.modules.ssh = {
    enable =
      lib.mkEnableOption "the unified OpenSSH server with pinned authorized keys"
      // {
        default = true;
      };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDxyfT6gCDvcoUXL6Sln2Gfqihgo4Cx4ggoXFIpxCZpq"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGoFjRGxdJUuPwS0wXCOmcvf8rOgeSGWtWQaCnLcRS4N"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMPfrsYAgx8QD5Kmic1AfdKC6vEV9v1ZnitfDp/c+PrQ"
      ];
      description = ''
        SSH public keys accepted for every user in modules.ssh.users. Pinned
        in the repo so a rebuild alone fully reproduces access on a fresh
        host. Rotate by editing this list and rebuilding.
      '';
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Login users that accept authorizedKeys.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = lib.mkDefault false;
        KbdInteractiveAuthentication = lib.mkDefault false;
        PermitRootLogin = lib.mkDefault "no";
      };
    };

    users.users = lib.genAttrs cfg.users (_: {
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    });

    # The old authorized-keys-sync unit cached fetched keys here; nothing
    # reads it anymore, so clean it up on rebuild.
    systemd.tmpfiles.rules = ["R /var/lib/authorized-keys"];
  };
}
