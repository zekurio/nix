{
  flake.modules.nixos.adam = {
    lib,
    pkgs,
    ...
  }: let
    mainUser = "zekurio";
    agentsProfile = "/home/${mainUser}/.local/state/nix/profiles/agents";
    # The default wrapper puts nixpkgs' Codex, Git, and gh ahead of the service
    # PATH. Leave provider selection to the independently updated agent profile.
    t3code = pkgs.t3code.override {
      enableCodex = false;
      enableGit = false;
      enableGitHub = false;
    };
  in {
    # Keep this code-execution surface private: plain HTTP is available on the
    # LAN, while T3 manages a tailnet-only HTTPS endpoint through Tailscale
    # Serve. Nothing is published through Caddy or Pangolin.
    systemd.services.t3code = {
      description = "T3 Code headless server";
      wantedBy = ["multi-user.target"];
      wants = [
        "network-online.target"
        "tailscaled-set.service"
      ];
      after = [
        "network-online.target"
        "tailscaled.service"
        "tailscaled-set.service"
      ];
      path = [
        pkgs.coreutils
        pkgs.git
        pkgs.gh
        pkgs.tailscale
      ];
      serviceConfig = {
        User = mainUser;
        Group = mainUser;
        SetLoginEnvironment = true;
        WorkingDirectory = "/home/${mainUser}";
        Restart = "always";
        RestartSec = 5;
      };
      script = ''
        export PATH="${agentsProfile}/bin:$PATH"

        exec ${lib.getExe' t3code "t3"} serve \
          --host 0.0.0.0 \
          --port 3773 \
          --tailscale-serve \
          --tailscale-serve-port 443
      '';
    };

    # Direct HTTP is private to the LAN and tailnet. Tailscale Serve terminates
    # HTTPS separately and proxies to the same local port.
    networking.firewall.interfaces.enp42s0.allowedTCPPorts = [3773];
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [3773];
  };
}
