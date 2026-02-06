{
  nixpkgs.overlays = [
    (import ./jellyfin-ffmpeg.nix)
    (import ./opencode.nix)
  ];
}
