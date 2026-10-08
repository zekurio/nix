{
  flake.modules.darwin.base = {
    nixpkgs.hostPlatform = "aarch64-darwin";

    system.stateVersion = 6;
    # nix-darwin master still passes the removed --toc-depth flag to
    # nixos-render-docs from current nixpkgs, breaking darwin-manual-html.
    # Skip the HTML manual and the uninstaller (whose embedded default system
    # also builds the manual) until upstream switches to --sidebar-depth.
    documentation.doc.enable = false;
    system.tools.darwin-uninstaller.enable = false;

    # Vanilla (upstream) Nix, managed declaratively by nix-darwin. These settings
    # are written to /etc/nix/nix.conf on activation; the shared substituters and
    # experimental features live in modules/nix.
    nix.enable = true;

    # Leave macOS's own /etc/pam.d/sudo_local in place; don't let nix-darwin manage
    # it. Setting the option (vs. forcing the etc file off) also removes the stale
    # `include sudo_local` line nix-darwin would otherwise add to /etc/pam.d/sudo.
    security.pam.services.sudo_local.enable = false;
  };
}
