{inputs, ...}: {
  flake.modules.nixos.base = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.modules.t3code;
    package = inputs.t3code.packages.${pkgs.stdenv.hostPlatform.system}.t3-code-nightly;
    codex = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
    user = config.users.users.zekurio;
    home = user.home;
    sessionVariables = config.home-manager.users.zekurio.home.sessionVariables;
  in {
    options.modules.t3code = {
      enable = lib.mkEnableOption "a persistent T3 Code environment";
      tailnet = lib.mkEnableOption "listen on the Tailscale IPv4 address";
      proxyAddress = lib.mkOption {
        type = lib.types.str;
        default = "100.77.212.45";
        description = "Tailscale IPv4 address of the Caddy host allowed to connect.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 3773;
        description = "T3 Code backend port.";
      };
    };

    config = lib.mkIf cfg.enable {
      users.users.zekurio.packages = [package];

      systemd.tmpfiles.rules = [
        "d ${home}/Git 0755 zekurio ${user.group} -"
      ];

      systemd.services.t3code = {
        description = "T3 Code remote environment";
        wantedBy = ["multi-user.target"];
        wants = ["network-online.target"];
        after = ["network-online.target"] ++ lib.optional cfg.tailnet "tailscaled.service";
        path = with pkgs;
          [
            package
            codex
            bash
            coreutils
            curl
            findutils
            git
            gnugrep
            gnused
            gnutar
            gzip
            nodejs_24
            openssh
            procps
            python3
            ripgrep
            unzip
            config.nix.package
          ]
          ++ lib.optional cfg.tailnet pkgs.tailscale;
        environment =
          lib.optionalAttrs (sessionVariables ? SSH_AUTH_SOCK) {
            inherit (sessionVariables) SSH_AUTH_SOCK;
          }
          // {
            HOME = home;
            T3CODE_HOME = "${home}/.t3";
            T3CODE_NO_BROWSER = "true";
            T3CODE_AUTO_BOOTSTRAP_PROJECT_FROM_CWD = "false";
          };
        script = ''
          # System services do not inherit the user's login PATH.
          export PATH="/run/wrappers/bin:${home}/.local/bin:${home}/.nix-profile/bin:/etc/profiles/per-user/zekurio/bin:/run/current-system/sw/bin:$PATH"
          ${
            if cfg.tailnet
            then ''
              # Wait for a tailnet address instead of binding a public interface.
              listen_host="$(tailscale ip -4)"
              test -n "$listen_host"
            ''
            else ''
              listen_host=127.0.0.1
            ''
          }
          exec t3 serve --host "$listen_host" --port ${toString cfg.port}
        '';
        serviceConfig = {
          User = "zekurio";
          Group = user.group;
          WorkingDirectory = "${home}/Git";
          Restart = "on-failure";
          RestartSec = 5;
          UMask = "0077";
        };
      };

      # Tailscale accepts traffic before nixos-fw. A separate input hook must
      # reject other clients before that accept rule runs.
      networking.firewall = lib.mkIf cfg.tailnet {
        extraCommands = ''
          ${lib.getExe pkgs.nftables} -f - <<'EOF'
          add table inet t3code
          flush table inet t3code
          add chain inet t3code input { type filter hook input priority -10; policy accept; }
          add rule inet t3code input iifname != { "lo", "tailscale0" } tcp dport ${toString cfg.port} drop
          add rule inet t3code input iifname "tailscale0" ip saddr != ${cfg.proxyAddress} tcp dport ${toString cfg.port} drop
          EOF
          iptables -A nixos-fw -i tailscale0 -s ${lib.escapeShellArg cfg.proxyAddress} -p tcp --dport ${toString cfg.port} -j nixos-fw-accept
        '';
        extraStopCommands = ''
          ${lib.getExe pkgs.nftables} delete table inet t3code 2>/dev/null || true
          iptables -D nixos-fw -i tailscale0 -s ${lib.escapeShellArg cfg.proxyAddress} -p tcp --dport ${toString cfg.port} -j nixos-fw-accept 2>/dev/null || true
        '';
      };
    };
  };
}
