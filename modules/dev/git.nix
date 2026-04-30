{
  lib,
  config,
  ...
}: let
  cfg = config.modules.dev;
  signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCcQoZiY9wkJ+U93isE8B3CKLmzL7TPzVh3ugE1WPJq";
  sshSigningProgram = "/run/current-system/sw/bin/ssh-keygen";
in {
  config = lib.mkIf cfg.enable {
    home-manager.users.zekurio = {config, ...}: {
      programs.git = {
        enable = true;
        signing = {
          key = signingKey;
          signByDefault = true;
        };
        settings = {
          user = {
            name = "Michael Schwieger";
            email = "git@zekurio.xyz";
          };
          init.defaultBranch = "main";
          pull.rebase = true;
          rebase.autoStash = true;
          gpg.format = "ssh";
          gpg.ssh.allowedSignersFile = "${config.home.homeDirectory}/.config/git/allowed_signers";
          "gpg \"ssh\"".program = sshSigningProgram;
        };
      };

      programs.jujutsu = {
        enable = true;
        settings = {
          user = {
            name = "Michael Schwieger";
            email = "git@zekurio.xyz";
          };
          signing = {
            behavior = "own";
            backend = "ssh";
            key = signingKey;
            backends.ssh.program = sshSigningProgram;
          };
        };
      };
    };
  };
}
