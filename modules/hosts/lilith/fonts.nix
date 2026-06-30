{pkgs, ...}: {
  fonts = {
    packages = [
      pkgs.fira
      pkgs.nerd-fonts.fira-code
      pkgs.roboto-slab
    ];

    fontconfig.defaultFonts = {
      sansSerif = ["Fira Sans"];
      serif = ["Roboto Slab"];
      monospace = ["FiraCode Nerd Font Mono"];
    };
  };

  home-manager.users.zekurio = {
    qt.kde.settings.kdeglobals.General = {
      font = "Fira Sans,10,-1,5,50,0,0,0,0,0";
      fixed = "FiraCode Nerd Font Mono,10,-1,5,50,0,0,0,0,0";
      menuFont = "Fira Sans,10,-1,5,50,0,0,0,0,0";
      smallestReadableFont = "Fira Sans,8,-1,5,50,0,0,0,0,0";
      toolBarFont = "Fira Sans,10,-1,5,50,0,0,0,0,0";
      activeFont = "Fira Sans,10,-1,5,75,0,0,0,0,0";
    };
  };
}
