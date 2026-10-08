{
  config,
  inputs,
  ...
}: let
  username = "zekurio";
  homeDirectory = "/Users/${username}";
in {
  flake.modules.darwin.base = {
    lib,
    pkgs,
    ...
  }: {
    imports = [inputs.home-manager.darwinModules.home-manager];

    system.primaryUser = username;

    # nix-darwin contributes "root" at the same priority; mkBefore keeps our
    # entries first in /etc/nix/nix.conf.
    nix.settings.trusted-users = lib.mkBefore [
      "root"
      "@admin"
      username
    ];

    programs.fish.enable = true;
    environment.shells = [pkgs.fish];
    users.knownUsers = [username];
    users.users.${username} = {
      uid = 501;
      gid = 20;
      description = "Michael";
      home = homeDirectory;
      shell = pkgs.fish;
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";

      users.${username} = {
        home = {
          inherit username homeDirectory;
        };

        imports = [
          config.flake.modules.homeManager.zekurio
        ];
      };
    };
  };
}
