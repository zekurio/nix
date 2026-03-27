{...}: let
  signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCcQoZiY9wkJ+U93isE8B3CKLmzL7TPzVh3ugE1WPJq";
in {
  home.file.".config/git/allowed_signers".text = ''
    git@zekurio.xyz ${signingKey}
  '';
}
