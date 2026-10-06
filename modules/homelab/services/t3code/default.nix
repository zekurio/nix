{inputs, ...}: {
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.t3code;
    user = "zekurio";
    home = config.users.users.${user}.home;
    port = 3773;
    package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.t3code;
  in {
    options.services.homelab.t3code.enable = lib.mkEnableOption "T3 Code nightly remote coding server";

    config = lib.mkIf cfg.enable {
      # Agents need the user's repositories, provider credentials and Git config.
      systemd.services.t3code = {
        description = "T3 Code nightly server";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        wants = ["network-online.target"];
        path = [
          config.home-manager.users.${user}.home.path
          pkgs.bash
          pkgs.coreutils
          pkgs.nix
        ];
        environment.HOME = home;
        serviceConfig = {
          ExecStart = "${lib.getExe package} serve --host 127.0.0.1 --port ${toString port}";
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
