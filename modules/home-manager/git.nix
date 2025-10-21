{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.homeManager.git;
in
{
  options.modules.homeManager.git = {
    enable =
      mkEnableOption "Git configuration with SSH signing"
      // {
        default = true;
      };
  };

  config = mkIf cfg.enable {
    home-manager.users.zekurio = { pkgs, lib, ... }: {
      programs.git = {
        enable = true;

        settings = {
          user.name = "Michael Schwieger";
          user.email = "git@zekurio.xyz";
          init.defaultBranch = "main";
          pull.rebase = true;
          rebase.autoStash = true;
          fetch.prune = true;
          core.autocrlf = "input";
          gpg.format = "ssh";
          gpg.ssh.program = "${pkgs.openssh}/bin/ssh-keygen";
          user.signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCcQoZiY9wkJ+U93isE8B3CKLmzL7TPzVh3ugE1WPJq";
          commit.gpgSign = true;
        };
      };

      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        matchBlocks."*".compression = true;
      };
    };
  };
}
