{inputs, ...}: {
  flake.modules.nixos.lilith = {pkgs, ...}: {
    modules.gaming.enable = true;

    home-manager.users.zekurio.agents.desktop = true;

    environment = {
      sessionVariables = {
        NIXOS_OZONE_WL = "1";
        ELECTRON_OZONE_PLATFORM_HINT = "auto";
      };
      systemPackages = with pkgs; [
        ddcutil
        feishin
        libnotify
        mpv
        inputs.jellium-desktop.packages.${pkgs.stdenv.hostPlatform.system}.default
        vesktop
        wl-clipboard
        zed-editor
      ];
    };
  };
}
