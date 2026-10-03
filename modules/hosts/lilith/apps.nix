{inputs, ...}: {
  flake.modules.nixos.lilith = {pkgs, ...}: {
    environment = {
      sessionVariables = {
        NIXOS_OZONE_WL = "1";
        ELECTRON_OZONE_PLATFORM_HINT = "auto";
      };
      systemPackages = with pkgs; [
        ddcutil
        inputs.delta.packages.${pkgs.stdenv.hostPlatform.system}.delta
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
