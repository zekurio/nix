{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.zellij-web;
    zellij = pkgs.zellij;
  in {
    options.services.homelab.zellij-web = {
      enable = lib.mkEnableOption "Zellij web client behind Caddy (LAN/tailnet only)";
      domain = lib.mkOption {
        type = lib.types.str;
        default = "term.${config.services.homelab.domains.zekurio}";
        description = ''
          Domain for the Zellij web virtual host. Private DNS is split-horizon
          and lives outside this repo: point this name at adam on the LAN
          resolver and at adam's Tailscale address in the external records.
        '';
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8082;
        description = "Loopback port the Zellij web server listens on.";
      };
    };

    config = lib.mkIf cfg.enable {
      # Zellij sessions belong to the user, so the web server runs as a user
      # service; linger for zekurio (modules/nixos/users/zekurio.nix) keeps it
      # alive without an active login session.
      systemd.user.services.zellij-web = {
        description = "Zellij web server";
        wantedBy = ["default.target"];
        # Auth is Zellij's own login-token layer (the vhost is LAN/tailnet-only
        # on top of that). Tokens are displayed once at creation and stored
        # hashed, so bootstrap one and park it in a file readable over SSH.
        preStart = ''
          tokenDir="$HOME/.local/share/zellij"
          tokenFile="$tokenDir/web-login-token"
          if [ ! -s "$tokenFile" ]; then
            mkdir -p "$tokenDir"
            ${zellij}/bin/zellij web --create-token \
              | ${pkgs.gnused}/bin/sed -n 's/^token_[0-9]*: //p' > "$tokenFile"
            chmod 600 "$tokenFile"
          fi
        '';
        serviceConfig = {
          ExecStart = "${zellij}/bin/zellij web --ip 127.0.0.1 --port ${toString cfg.port}";
          Restart = "on-failure";
        };
      };

      services.homelab.caddy.virtualHosts.zellij-web = {
        inherit (cfg) domain;
        reverseProxy = "127.0.0.1:${toString cfg.port}";
      };
    };
  };
}
