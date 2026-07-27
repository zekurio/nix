{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.newt;
  in {
    options.services.homelab.newt = {
      enable = lib.mkEnableOption ''
        the Newt tunnel client that registers this host as a site on the
        ramiel Pangolin edge. Newt dials out over WireGuard in user space,
        so no inbound port has to be opened for it
      '';

      endpoint = lib.mkOption {
        type = lib.types.str;
        default = "https://pangolin.zekurio.me";
        description = "Pangolin dashboard this site registers with.";
      };
    };

    config = lib.mkIf cfg.enable {
      services.newt = {
        enable = true;
        settings = {
          endpoint = cfg.endpoint;
          log-level = "INFO";
        };
        # NEWT_ID and NEWT_SECRET come from the site created in Pangolin; the
        # upstream module reads them as environment variables, which also keeps
        # them out of the Nix store.
        environmentFile = config.sops.secrets.newt_env.path;
      };

      # Read by systemd as root before the unit drops to its DynamicUser.
      sops.secrets.newt_env = {
        mode = "0400";
      };
    };
  };
}
