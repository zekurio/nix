{inputs, ...}: {
  flake.modules.nixos.lilith = {
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
        sddm = {
          enable = true;
          wayland.enable = true;
        };
      };
      printing.enable = true;
    };

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
  };
}
