{
  flake.modules.nixos.lilith = {
    # COSMIC stores secrets in gnome-keyring, whose module only unlocks it from
    # the login PAM service. cosmic-greeter authenticates through greetd, so
    # without this every session would prompt for the keyring password.
    security.pam.services.greetd.enableGnomeKeyring = true;
  };
}
