{
  flake.modules.nixos.lilith = {
    lib,
    pkgs,
    ...
  }: {
    fonts = {
      packages = with pkgs; [
        fira
        nerd-fonts.fira-code
        roboto-slab
      ];
      fontconfig.defaultFonts = {
        sansSerif = ["Fira Sans"];
        serif = ["Roboto Slab"];
        monospace = ["FiraCode Nerd Font Mono"];
      };
    };

    # The shared profile disables user fontconfig on macOS and headless hosts;
    # Steam reads the user's fontconfig configuration on this desktop.
    home-manager.users.zekurio.fonts.fontconfig.enable = lib.mkForce true;
  };
}
