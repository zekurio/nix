{inputs, ...}: {
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.cliproxyapi;
    domain = "cpa.${config.services.homelab.domains.zekurio}";
    port = 8317;
  in {
    options.services.homelab.cliproxyapi = {
      enable = lib.mkEnableOption "CLIProxyAPI subscription-CLI proxy with Caddy integration";
    };

    config = lib.mkIf cfg.enable {
      services.cliproxyapi = {
        enable = true;
        package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.cli-proxy-api;
        settings = {
          host = "127.0.0.1";
          inherit port;
          # The upstream module resolves `_secret` paths at start via
          # LoadCredential, so root reads the files and no owner is needed.
          api-keys = [{_secret = config.sops.secrets.cliproxyapi_api_key.path;}];
          remote-management = {
            # Caddy proxies from loopback, so the daemon would treat every
            # request as local anyway; being explicit keeps the management
            # panel working if that ever changes. Exposure is bounded by the
            # private vhost (LAN + tailnet only).
            allow-remote = true;
            secret-key._secret = config.sops.secrets.cliproxyapi_management_key.path;
          };
          usage-statistics-enabled = true;
        };
      };

      # The CLI login flow (`cliproxyapi --claude-login -no-browser` as the
      # service user) needs the binary on PATH; see the nixpkgs module docs.
      environment.systemPackages = [config.services.cliproxyapi.package];

      sops.secrets = {
        cliproxyapi_api_key.restartUnits = ["cliproxyapi.service"];
        cliproxyapi_management_key.restartUnits = ["cliproxyapi.service"];
      };

      services.homelab.caddy.virtualHosts."cliproxyapi" = {
        inherit domain;
        # Private: LAN and tailnet only. The API keys are the only auth in
        # front of paid provider quotas, so this stays off the internet.
        reverseProxy = "127.0.0.1:${toString port}";
      };
    };
  };
}
