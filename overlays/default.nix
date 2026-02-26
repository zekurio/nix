{
  nixpkgs.overlays = [
    (import ./jellyfin-ffmpeg.nix)
    (import ./navidrome.nix)
  ];
}
