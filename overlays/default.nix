inputs: {
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "electron-36.9.5"
  ];

  nixpkgs.overlays = [
    # Add overlays here
    (import ./jellyfin-ffmpeg.nix)
    (import ./unstable.nix inputs)
    (import ./quickshell.nix inputs)
  ];
}
