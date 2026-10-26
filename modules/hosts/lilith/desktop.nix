{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    konsole
    okular
  ];
  # Plasma enables the whole PIM suite: KMail, Kontact, Merkuro and Akonadi.
  programs.kde-pim.enable = false;
  services = {
    desktopManager.plasma6.enable = true;
    displayManager = {
      defaultSession = "plasma";
      # Plasma's Login Screen settings page ships with this greeter, not SDDM.
      # Its "Apply Plasma Settings" copies the session's colours, fonts and
      # monitor layout to the greeter, which otherwise stays Breeze Light.
      plasma-login-manager.enable = true;
    };
    printing.enable = true;
  };

  # The NixOS module hands the greeter an XDG_DATA_DIRS holding only the
  # session directory, so it cannot find icon themes from the system profile
  # and logs `Icon theme "Papirus-Dark" not found`. mkForce replaces that
  # value because the option is a plain string, not a list that would merge.
  systemd.user.services.plasma-login.environment.XDG_DATA_DIRS = lib.mkForce (
    lib.concatStringsSep ":" [
      "${config.services.displayManager.sessionData.desktops}/share"
      "/run/current-system/sw/share"
    ]
  );

  home-manager.users.zekurio = {
    imports = [inputs.plasma-manager.homeModules.plasma-manager];
    # overrideConfig stays off, so settings this flake leaves undeclared
    # remain editable in System Settings.
    programs.plasma = {
      enable = true;
      # plasma-manager writes its web shortcut options even when none are
      # set, and its empty preferred list would replace KDE's built-in one.
      # null drops the key instead.
      configFile.kuriikwsfilterrc.General.PreferredWebShortcuts = lib.mkForce null;
    };
  };
}
