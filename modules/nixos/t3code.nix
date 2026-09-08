{inputs, ...}: let
  packageFor = pkgs:
    pkgs.callPackage ./_t3code.nix {
      agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
    };
in {
  flake.modules.nixos.base = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.modules.t3code;
    package = packageFor pkgs;
    home = "/var/lib/t3code";
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
      # Agents have their own home and credentials, without the owner's sudo
      # rights or access to private shares. SSH also permits provider login.
      users.groups.t3code = {};
      users.users.t3code = {
        isNormalUser = true;
        group = "t3code";
        inherit home;
        createHome = true;
        homeMode = "0700";
        shell = pkgs.fish;
        openssh.authorizedKeys.keys = config.modules.ssh.authorizedKeys;
        packages = [package inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex];
      };

      systemd.tmpfiles.rules = [
        "d ${home}/projects 0700 t3code t3code -"
        "d ${home}/.agents 0700 t3code t3code -"
        "L+ ${home}/.agents/skills - - - - ${inputs.agent-stuff}/skills"
      ];

      systemd.services.t3code = {
        description = "T3 Code remote environment";
        wantedBy = ["multi-user.target"];
        wants = ["network-online.target"];
        after = ["network-online.target"] ++ lib.optional cfg.tailnet "tailscaled.service";
        path = with pkgs;
          [
            package
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
        environment = {
          HOME = home;
          T3CODE_HOME = "${home}/.t3";
          T3CODE_NO_BROWSER = "true";
          T3CODE_AUTO_BOOTSTRAP_PROJECT_FROM_CWD = "false";
        };
        script = ''
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
          User = "t3code";
          Group = "t3code";
          WorkingDirectory = "${home}/projects";
          Restart = "on-failure";
          RestartSec = 5;
          UMask = "0077";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [home];
          InaccessiblePaths = ["-/tank" "-/mnt/downloads"];
          PrivateTmp = true;
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
