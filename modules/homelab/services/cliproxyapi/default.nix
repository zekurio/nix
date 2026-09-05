{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.cliproxyapi;
    package = pkgs.callPackage ./_package.nix {};
    stateDir = "/var/lib/cliproxyapi";
    port = 8317;
    settings = pkgs.writeText "cliproxyapi-settings.json" (builtins.toJSON {
      host = "127.0.0.1";
      inherit port;
      auth-dir = "${stateDir}/auth";
      remote-management = {
        # Caddy forwards the client IP. Its private vhost applies the IP rule.
        allow-remote = true;
        disable-auto-update-panel = true;
      };
      routing.strategy = "round-robin";
      quota-exceeded = {
        switch-project = true;
        switch-preview-model = false;
      };
      ws-auth = true;
      usage-statistics-enabled = true;
      request-log = false;
      logging-to-file = false;
    });
  in {
    options.services.homelab.cliproxyapi.enable = lib.mkEnableOption "private subscription API proxy";

    config = lib.mkIf cfg.enable {
      users.groups.cliproxyapi = {};
      users.users.cliproxyapi = {
        isSystemUser = true;
        group = "cliproxyapi";
        home = stateDir;
      };

      environment.systemPackages = [package];
      systemd.services.cliproxyapi = {
        description = "CLIProxyAPI subscription proxy";
        wantedBy = ["multi-user.target"];
        wants = ["network-online.target"];
        after = ["network-online.target"];
        # Keys and OAuth tokens stay in private host state, outside the Nix store.
        # Rebuild the config on restart so UI edits cannot remove network guards.
        preStart = ''
          for key in api-key management-key; do
            if [ ! -s "${stateDir}/$key" ]; then
              ${pkgs.openssl}/bin/openssl rand -hex 32 > "${stateDir}/$key"
            fi
          done
          mkdir -p ${stateDir}/auth
          ${pkgs.jq}/bin/jq \
            --rawfile apiKey ${stateDir}/api-key \
            --rawfile managementKey ${stateDir}/management-key \
            '. + {"api-keys": [($apiKey | rtrimstr("\n"))]} |
             ."remote-management"."secret-key" = ($managementKey | rtrimstr("\n"))' \
            ${settings} > ${stateDir}/config.yaml
        '';
        serviceConfig = {
          ExecStart = "${lib.getExe package} -config ${stateDir}/config.yaml";
          User = "cliproxyapi";
          Group = "cliproxyapi";
          StateDirectory = "cliproxyapi";
          StateDirectoryMode = "0700";
          WorkingDirectory = stateDir;
          Restart = "on-failure";
          RestartSec = 5;
          UMask = "0077";
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
          CapabilityBoundingSet = "";
        };
      };

      services.homelab.caddy.virtualHosts.cliproxyapi = {
        domain = "ai.${config.services.homelab.domains.zekurio}";
        reverseProxy = "127.0.0.1:${toString port}";
      };
    };
  };
}
