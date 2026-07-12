{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    openssh
  ];

  homebrew = {
    enable = true;
    user = "zekurio";
    taps = [
      {
        name = "kgarner7/feishin";
        trusted = true;
      }
    ];
    casks = [
      "feishin"
      "ghostty"
      "helium-browser"
      "iina"
      "mullvad-vpn"
      "notion"
      "steam"
      "tailscale-app"
      "vesktop"
      "zed"
    ];
    caskArgs.appdir = "/Applications";
    onActivation = {
      cleanup = "uninstall";
      extraEnv.HOMEBREW_NO_ANALYTICS = "1";
      # Keep `darwin-rebuild switch` idempotent: no index auto-update or cask
      # upgrades during activation. Upgrade deliberately via `brew upgrade`.
      upgrade = false;
    };
  };
}
