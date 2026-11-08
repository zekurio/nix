{
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.services.homelab.knot;
  knot = config.services.tangled.knot-rs;
  domain = "knot.${config.services.homelab.domains.zekurio}";
in {
  imports = [
    inputs.tangled.nixosModules.knot-rs
  ];

  options.services.homelab.knot = {
    enable = lib.mkEnableOption "the Tangled knot that hosts my repositories";
  };

  config = lib.mkIf cfg.enable {
    services.tangled.knot-rs = {
      enable = true;
      environmentFile = config.sops.secrets.knot_env.path;
      settings = {
        server = {
          # Also the knot's did:web identity, which every repo hangs off.
          hostname = domain;
          # The first entry is the owner the knot advertises.
          admins = ["did:plc:c5tl5gu27hssisgzp4x3mmvq"];
          # tangled.org's clone URLs never carry a port, so the knot takes
          # 22 and adam's sshd moves to 2200. Below 1024 the module grants
          # CAP_NET_BIND_SERVICE and turns PrivateUsers off.
          ssh_listen_addr = "[::]:22";
        };
        # The default for repos as they are created; existing repos never
        # convert. SHA-256 repos can't mirror to or from GitHub, and Nix
        # can't fetch them as flake inputs.
        git.object_format = "sha1";
        atproto.plc_directory = "https://plc.directory";
        contact.email = "admin@zekurio.me";
        # Holds the attachments of issues and pulls as well as LFS objects.
        # The module gains this default after v1.20.0.
        lfs.store_path = "${knot.stateDir}/lfs";
        # Caddy is the only proxy and dials the knot over loopback. Caddy
        # itself trusts no upstream proxy, so it replaces X-Forwarded-For
        # with the peer it saw, and the rate limiter keys on real clients.
        xrpc = {
          trusted_proxy_header = "x-forwarded-for";
          trusted_proxies = ["127.0.0.1" "::1"];
        };
      };
    };

    # KNOT_MASTER_KEY unseals settings.secrets.sealed_key_file. Each is
    # useless without the other, and a new key can't read the old file, so
    # never rotate it in place.
    sops.secrets.knot_env = {
      owner = knot.user;
      group = knot.group;
      mode = "0400";
      restartUnits = ["knot-rs.service"];
    };

    services.homelab.backup.stopUnits = ["knot-rs.service"];

    services.homelab.caddy.virtualHosts.knot = {
      inherit domain;
      # tangled.org's appview and indexer call the knot, and anyone may
      # clone over HTTPS. Only DIDs the knot admits can push.
      public = true;
      reverseProxy = knot.settings.server.listen_addr;
    };
  };
}
