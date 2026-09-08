{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.t3code;
  in {
    options.services.homelab.t3code = {
      enable = lib.mkEnableOption "private T3 Code environments through Caddy";
      lilithBackend = lib.mkOption {
        type = lib.types.str;
        default = "10.0.0.3:3773";
        description = "Lilith's T3 Code backend on the LAN.";
      };
    };

    config = lib.mkIf cfg.enable {
      modules.t3code.enable = true;
      services.homelab.caddy.virtualHosts = {
        t3code = {
          domain = "adam.${config.services.homelab.domains.zekurio}";
          reverseProxy = "127.0.0.1:${toString config.modules.t3code.port}";
        };
        t3code-lilith = {
          domain = "lilith.${config.services.homelab.domains.zekurio}";
          reverseProxy = cfg.lilithBackend;
        };
      };
    };
  };
}
