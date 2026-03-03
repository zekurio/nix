{
  nixpkgs.overlays = [
    (import ./jellyfin-ffmpeg.nix)
  ];
}
