inputs: {
  nixpkgs.overlays = [
    (import ./jellyfin-ffmpeg.nix)
    (import ./unstable.nix inputs)
  ];
}
