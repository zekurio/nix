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
    # Keep this code-execution surface on the tailnet. The desktop client
    # cannot pass a Pangolin SSO gate, while T3's own pairing token is not a
    # sufficient outer boundary for public exposure.
    systemd.services.t3code = {
      description = "T3 Code headless server";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target" "tailscaled.service"];
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

        # tailscaled being active does not mean its interface has an address
        # yet, so wait for one rather than asking T3 to bind an empty host.
        until ts_ip="$(tailscale ip -4 2>/dev/null)" && [ -n "$ts_ip" ]; do
          sleep 1
        done

        exec ${lib.getExe' t3code "t3"} serve --host "$ts_ip"
      '';
    };

    # T3's default server port, reachable only through the Tailscale interface.
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [3773];
  };
}
