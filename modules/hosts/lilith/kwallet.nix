{
  flake.modules.nixos.lilith = {
    config,
    lib,
    ...
  }: {
    # pam_kwallet starts ksecretd from the login manager's PAM session, so it
    # inherits the daemon's environment rather than the Plasma session's. The
    # nixpkgs module narrows XDG_DATA_DIRS to the session files, which hides
    # share/union; the Union widget style then dereferences its missing rules
    # and segfaults, and the wallet never unlocks at login. No session files
    # live under the system profile, so the greeter's session list is unchanged.
    systemd.services.plasmalogin.environment.XDG_DATA_DIRS = lib.mkForce (
      lib.concatStringsSep ":" [
        "${config.services.displayManager.sessionData.desktops}/share"
        "/run/current-system/sw/share"
      ]
    );
  };
}
