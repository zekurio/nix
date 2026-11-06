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
      "1password"
      "feishin"
      "fluxer"
      "ghostty"
      "helium-browser"
      "iina"
      "legcord"
      "mullvad-vpn"
      "notion"
      "signal"
      "steam"
      "t3-code"
      "tailscale-app"
      "zed"
    ];
    caskArgs.appdir = "/Applications";
    # Without this, brew refetches every tap over HTTPS on ordinary commands.
    global.autoUpdate = false;
    onActivation = {
      # Homebrew holds only what is listed here; zap also removes the app data
      # of anything dropped from the list.
      cleanup = "zap";
      extraEnv.HOMEBREW_NO_ANALYTICS = "1";
      # Keep rebuilds deterministic; upgrade casks deliberately with Homebrew.
      upgrade = false;
    };
  };
}
