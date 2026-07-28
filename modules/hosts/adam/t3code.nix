{inputs, ...}: {
  flake.modules.nixos.adam = {
    lib,
    pkgs,
    ...
  }: let
    mainUser = "zekurio";
    agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
    # The default wrapper toggles bake nixpkgs' codex and gh into PATH ahead
    # of anything the unit supplies; disable them so the service path below
    # decides, with the same llm-agents builds the interactive shell uses.
    t3code = pkgs.t3code.override {
      enableCodex = false;
      enableGit = false;
      enableGitHub = false;
    };
  in {
    # Deliberately not a Pangolin resource or Caddy vhost: the desktop client
    # cannot pass an SSO gate at the edge, so publishing it would mean putting
    # a code-execution surface on the internet behind t3's pairing tokens
    # alone. The tailnet is the outer gate instead.
    systemd.services.t3code = {
      description = "T3 Code headless server";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target" "tailscaled.service"];
      path = [
        agents.claude-code
        agents.codex
        pkgs.git
        pkgs.gh
        pkgs.tailscale
      ];
      serviceConfig = {
        User = mainUser;
        Group = mainUser;
        # systemd leaves $HOME unset for User= services without this, and t3
        # plus every agent CLI it spawns resolve their state through it.
        SetLoginEnvironment = true;
        WorkingDirectory = "/home/${mainUser}";
        Restart = "always";
        RestartSec = 5;
      };
      script = ''
        # tailscaled being active does not mean the interface has its address
        # yet; wait for one instead of binding an empty host.
        until ts_ip="$(tailscale ip -4 2>/dev/null)" && [ -n "$ts_ip" ]; do
          sleep 1
        done
        exec ${lib.getExe' t3code "t3"} serve --host "$ts_ip"
      '';
    };

    # 3773 is t3's default listen port.
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [3773];
  };
}
