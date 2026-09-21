{
  flake.modules.darwin.sachiel = {pkgs, ...}: let
    fluxerTap = pkgs.runCommandLocal "fluxer-homebrew-tap" {} ''
      mkdir -p "$out/Casks/f"
      cp ${./homebrew/fluxer.rb} "$out/Casks/f/fluxer.rb"
    '';
  in {
    # nix-homebrew uses the full directory name; brew uses "zekurio/fluxer".
    nix-homebrew.taps."zekurio/homebrew-fluxer" = fluxerTap;

    homebrew = {
      enable = true;
      user = "zekurio";
      taps = [
        {
          name = "kgarner7/feishin";
          trusted = true;
        }
        {
          name = "zekurio/fluxer";
          trusted = true;
        }
      ];
      casks = [
        "1password"
        "discord"
        "feishin"
        "ghostty"
        "helium-browser"
        "iina"
        "mullvad-vpn"
        "notion"
        "steam"
        "tailscale-app"
        "zekurio/fluxer/fluxer"
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
  };
}
