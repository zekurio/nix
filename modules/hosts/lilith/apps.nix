{
  config,
  inputs,
  pkgs,
  ...
}: {
  modules.gaming.enable = true;

  home-manager.users.zekurio.agents = {
    desktop = true;
    # The emulator needs /dev/kvm, which only exists with SVM enabled in the
    # firmware; README.md has the procedure.
    android.enable = true;
  };

  environment = {
    sessionVariables = {
      NIXOS_OZONE_WL = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
    };
    systemPackages = with pkgs; [
      ddcutil
      libnotify
      mpv
      inputs.jellium-desktop.packages.${pkgs.stdenv.hostPlatform.system}.default
      wl-clipboard
      # Launches Zed with the vrouter key in its provider variables.
      config.home-manager.users.zekurio.agents.vrouter.zedPackage
    ];
  };
}
