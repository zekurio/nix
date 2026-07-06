{
  inputs,
  lib,
  pkgs,
  ...
}: let
  username = "zekurio";
  homeDirectory = "/Users/${username}";
in {
  imports = [
    ../../nixpkgs
  ];

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

  # Nix itself is managed outside nix-darwin (Determinate Nix), so nix.enable is
  # off. Any nix.settings here would be silently dropped by nix-darwin
  # (its whole config is gated on nix.enable), so substituters and trusted keys
  # live in flake.nix `nixConfig` instead.
  nix.enable = false;

  # Leave macOS's own /etc/pam.d/sudo_local in place; don't let nix-darwin manage
  # it. Setting the option (vs. forcing the etc file off) also removes the stale
  # `include sudo_local` line nix-darwin would otherwise add to /etc/pam.d/sudo.
  security.pam.services.sudo_local.enable = false;

  nix-homebrew = {
    enable = true;
    enableFishIntegration = true;
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
        ../../home/zekurio
      ];
    };
  };
}
