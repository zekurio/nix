{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.t3code;
    user = "zekurio";
    home = config.users.users.${user}.home;
    agents = config.home-manager.users.${user}.agents;
    port = 3773;
  in {
    options.services.homelab.t3code.enable = lib.mkEnableOption "T3 Code nightly remote coding server";

    config = lib.mkIf cfg.enable {
      # Agents need the user's repositories, provider credentials and Git config.
      systemd.services.t3code = {
        description = "T3 Code nightly server";
        wantedBy = ["multi-user.target"];
        # Home Manager's activation creates the agents profile.
        after = ["network-online.target" "home-manager-${user}.service"];
        wants = ["network-online.target" "home-manager-${user}.service"];
        # The profile path never changes, so restart on a new pinned build
        # here. agents-update leaves the restart to the user.
        restartTriggers = [agents.pinned];
        path = [
          config.home-manager.users.${user}.home.path
          pkgs.bash
          pkgs.coreutils
          pkgs.nix
        ];
        environment.HOME = home;
        serviceConfig = {
          ExecStart = "${agents.profile}/bin/t3 serve --host 127.0.0.1 --port ${toString port}";
          User = user;
          Group = config.users.users.${user}.group;
          WorkingDirectory = home;
          Restart = "on-failure";
          RestartSec = 5;
          UMask = "0077";
        };
      };

      services.homelab.caddy.virtualHosts.t3code = {
        domain = "t3code.${config.services.homelab.domains.zekurio}";
        reverseProxy = "127.0.0.1:${toString port}";
      };
    };
  };
}
