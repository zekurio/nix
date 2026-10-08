{
  flake.modules.nixos.lilith = {pkgs, ...}: {
    environment = {
      plasma6.excludePackages = [pkgs.kdePackages.konsole];
      systemPackages = [
        pkgs.klassy
        pkgs.papirus-icon-theme
      ];
    };
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
  };
}
