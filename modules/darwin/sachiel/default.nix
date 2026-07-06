{
  lib,
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    openssh
    # GUI apps installed via Nix; nix-darwin copies these into /Applications/Nix Apps.
    feishin
    iina
    vesktop
    inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.helium
  ];

  # Register Nix-installed .app bundles with LaunchServices so they appear in
  # Spotlight and Launchpad; nix-darwin only copies them into /Applications.
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
    casks = [
      "bitwarden"
      "ghostty"
      "mullvad-vpn"
      "notion"
      "steam"
      "tailscale-app"
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
