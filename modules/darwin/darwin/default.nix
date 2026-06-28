{
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    git
    openssh
  ];

  system.activationScripts.applications.text = lib.mkAfter ''
    launchServices='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'

    if [ -x "$launchServices" ]; then
      echo "registering /Applications/Nix Apps with LaunchServices..." >&2
      for app in /Applications/Nix\ Apps/*.app; do
        [ -d "$app" ] || continue
        "$launchServices" -f "$app" || true
      done
    fi
  '';

  homebrew = {
    enable = true;
    user = "zekurio";
    taps = [
      {
        name = "kgarner7/feishin";
        trusted = true;
      }
      "steipete/tap"
    ];
    casks = [
      "bitwarden"
      "codexbar"
      "feishin"
      "ghostty"
      "helium-browser"
      "iina"
      "mullvad-vpn"
      "notion"
      "raycast"
      "steam"
      "tailscale-app"
      "vesktop"
      "zed"
    ];
    caskArgs.appdir = "/Applications";
    onActivation = {
      autoUpdate = true;
      cleanup = "none";
      extraEnv.HOMEBREW_NO_ANALYTICS = "1";
      upgrade = true;
    };
    global.autoUpdate = true;
  };

  home-manager.users.zekurio.programs.ssh.settings = {
    adam = {
      HostName = "10.0.0.2";
      User = "zekurio";
      AddKeysToAgent = "yes";
      IdentityFile = "~/.ssh/id_ed25519";
    };
    "10.0.0.2" = {
      User = "zekurio";
      AddKeysToAgent = "yes";
      IdentityFile = "~/.ssh/id_ed25519";
    };
  };
}
