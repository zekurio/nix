{
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
      cleanup = "none";
      extraEnv.HOMEBREW_NO_ANALYTICS = "1";
      # Keep rebuilds deterministic; upgrade casks deliberately with Homebrew.
      upgrade = false;
    };
  };
}
