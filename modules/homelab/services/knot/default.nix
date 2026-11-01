{
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.services.homelab.knot;
  knot = config.services.tangled.knot-rs;
  domain = "knot.${config.services.homelab.domains.zekurio}";
  port = 5555;
  # The knot's own SSH server, git only: no shell, no passwords, and only
  # keys published on an atproto account get in. sshd keeps 22 on adam, so
  # the router maps the public port 22 to this one; clone URLs need no port.
  sshPort = 2222;
in {
  imports = [inputs.tangled.nixosModules.knot-rs];

  options.services.homelab.knot.enable = lib.mkEnableOption "the Tangled knot git server with Caddy integration";

  config = lib.mkIf cfg.enable {
    services.tangled.knot-rs = {
      enable = true;
      # Supplies KNOT_MASTER_KEY, which unseals the knot's signing keys.
      # The sealed store in stateDir is useless without it, and the other
      # way round.
      environmentFile = config.sops.secrets.knot_env.path;
      # Opens sshPort only; the HTTP listener stays on loopback behind Caddy.
      openFirewall = true;
      settings = {
        server = {
          # Also the knot's did:web identity, so it must never change.
          hostname = domain;
          # zekurio.me. The first entry is the owner the knot advertises.
          admins = ["did:plc:e4xhurcsnmvwkkmrk5z4lare"];
          listen_addr = "127.0.0.1:${toString port}";
          ssh_listen_addr = "[::]:${toString sshPort}";
        };
        atproto.plc_directory = "https://plc.directory";
        contact.email = "admin@${config.services.homelab.domains.zekurio}";
        # Applies only to repositories created afterwards. SHA-256 repos
        # cannot exchange objects with SHA-1 remotes such as GitHub.
        git.object_format = "sha256";
        lfs.store_path = "${knot.stateDir}/lfs";
        # Caddy appends the client to X-Forwarded-For. Honouring it from
        # loopback alone keeps the rate limiter per client.
        xrpc = {
          trusted_proxy_header = "x-forwarded-for";
          trusted_proxies = ["127.0.0.1" "::1"];
        };
      };
    };

    sops.secrets.knot_env = {
      owner = knot.user;
      group = knot.group;
      mode = "0400";
      # EnvironmentFile is read once at start, so a rotated key would
      # otherwise stay unused until an unrelated restart.
      restartUnits = ["knot-rs.service"];
    };

    # Git is the knot's database: repos/ holds every repository and the
    # ACLs, next to the sealed keys and LFS store in stateDir.
    services.homelab.backup.stopUnits = ["knot-rs.service"];

    # Public: tangled.org reads repositories and events over this host,
    # and pushes are checked against keys published on the atproto account.
    services.homelab.caddy.virtualHosts.knot = {
      inherit domain;
      public = true;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
