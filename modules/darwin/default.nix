{
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.stateVersion = 6;

  # Vanilla (upstream) Nix, managed declaratively by nix-darwin. These settings
  # are written to /etc/nix/nix.conf on activation; the shared substituters and
  # experimental features live in modules/common/nix.nix.
  nix.enable = true;

  # Leave macOS's own /etc/pam.d/sudo_local in place; don't let nix-darwin manage
  # it. Setting the option (vs. forcing the etc file off) also removes the stale
  # `include sudo_local` line nix-darwin would otherwise add to /etc/pam.d/sudo.
  security.pam.services.sudo_local.enable = false;
}
