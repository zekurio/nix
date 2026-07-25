{config, ...}: {
  flake.modules.nixos.base = {
    inputs,
    pkgs,
    ...
  }: let
    username = "zekurio";
  in {
    nix.settings.trusted-users = [username];

    programs = {
      fish.enable = true;
      vim = {
        enable = true;
        defaultEditor = true;
      };
    };

    environment.shells = [
      pkgs.fish
      pkgs.nushell
    ];

    users = {
      defaultUserShell = pkgs.nushell;

      users.${username} = {
        shell = pkgs.nushell;
        # Keeps the user's systemd instance (and XDG_RUNTIME_DIR) alive after
        # the last SSH session ends, so a detached zellij session stays
        # reattachable instead of dying with the runtime dir.
        linger = true;
        uid = 1000;
        isNormalUser = true;
        # A yescrypt hash of a strong password; committing it is an accepted
        # trade-off (offline cracking is infeasible, and SSH password auth is
        # disabled everywhere anyway).
        hashedPassword = "$y$j9T$WeZ0opXmn8yWxOwDH6/bL0$wtARyV6xTpo4OYgGpy9W0EAhJtJPYWXlwqaaVsfZQN/";
        extraGroups = [
          "wheel"
          "users"
          "video"
          "podman"
          "input"
          "i2c"
        ];
        group = username;
      };

      groups.${username}.gid = 1000;
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      extraSpecialArgs = {inherit inputs;};

      users.${username}.imports = [
        config.flake.modules.homeManager.zekurio
      ];
    };
  };
}
