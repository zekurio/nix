{pkgs, ...}: {
  programs = {
    gamemode.enable = true;
    gamescope = {
      enable = true;
      capSysNice = true;
    };
    steam = {
      enable = true;
      gamescopeSession.enable = true;
      extraCompatPackages = [
        pkgs.proton-ge-bin
      ];
    };
  };

  environment.systemPackages = [
    pkgs.heroic
    pkgs.mangohud
    pkgs.protonup-qt
  ];
}
