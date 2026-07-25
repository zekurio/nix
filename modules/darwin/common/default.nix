{config, ...}: let
  username = "zekurio";
  homeDirectory = "/Users/${username}";
in {
  flake.modules.darwin.base = {
    inputs,
    lib,
    pkgs,
    ...
  }: {
    nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin";

    system = {
      primaryUser = username;
      stateVersion = 6;
    };
    # nix-darwin master still passes the removed --toc-depth flag to
    # nixos-render-docs from current nixpkgs, breaking darwin-manual-html.
    # Skip the HTML manual and the uninstaller (whose embedded default system
    # also builds the manual) until upstream switches to --sidebar-depth.
    documentation.doc.enable = false;
    system.tools.darwin-uninstaller.enable = false;

    environment.shells = [pkgs.nushell];
    users.knownUsers = [username];
    users.users.${username} = {
      uid = 501;
      gid = 20;
      description = "Michael";
      home = homeDirectory;
      shell = pkgs.nushell;
    };

    # Vanilla (upstream) Nix, managed declaratively by nix-darwin. These settings
    # are written to /etc/nix/nix.conf on activation.
    nix = {
      enable = true;
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        # The deferred `flake.modules.darwin.base` slot nests these definitions
        # one `imports` level below nix-darwin's own baseModules, which flips the
        # equal-priority list-merge order for `trusted-users`/`trusted-public-keys`
        # (nix-darwin appends "root"/"cache.nixos.org-1" at plain priority). The
        # pre-dendritic module set these directly at top level, so our entries came
        # first. mkBefore restores that order independent of module nesting; the
        # resulting /etc/nix/nix.conf is byte-identical.
        trusted-users = lib.mkBefore [
          "root"
          "@admin"
          username
        ];
        substituters = (import ../../_caches.nix).substituters;
        trusted-public-keys = lib.mkBefore (import ../../_caches.nix).trusted-public-keys;
        auto-optimise-store = true;
      };
    };

    # Leave macOS's own /etc/pam.d/sudo_local in place; don't let nix-darwin manage
    # it. Setting the option (vs. forcing the etc file off) also removes the stale
    # `include sudo_local` line nix-darwin would otherwise add to /etc/pam.d/sudo.
    security.pam.services.sudo_local.enable = false;

    nix-homebrew = {
      enable = true;
      autoMigrate = true;
      enableFishIntegration = false;
      user = username;
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      extraSpecialArgs = {inherit inputs;};

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
