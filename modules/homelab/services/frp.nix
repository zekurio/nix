{
  config,
  lib,
  ...
}: let
  cfg = config.services.frp-wrapped;
  serverAddr = "shamshel.zekurio.xyz";
  serverPort = 7000;
  slskdPort = 50300;
in {
  options.services.frp-wrapped = {
    enable = lib.mkEnableOption "FRP client tunnel to VPS with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    services.frp.instances.default = {
      enable = true;
      role = "client";
      environmentFiles = [config.sops.secrets.frp_env.path];
      settings = {
        serverAddr = serverAddr;
        serverPort = serverPort;
        auth = {
          method = "token";
          token = "{{ .Envs.FRP_TOKEN }}";
        };
        proxies = [
          {
            name = "http";
            type = "tcp";
            localIP = "127.0.0.1";
            localPort = 80;
            remotePort = 80;
          }
          {
            name = "https";
            type = "tcp";
            localIP = "127.0.0.1";
            localPort = 443;
            remotePort = 443;
          }
          {
            name = "slskd";
            type = "tcp";
            localIP = "127.0.0.1";
            localPort = slskdPort;
            remotePort = slskdPort;
          }
        ];
      };
    };

    # SOPS secret for FRP environment variables
    sops.secrets.frp_env = {
      mode = "0400";
    };
  };
}
