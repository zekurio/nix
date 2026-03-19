{
  nixpkgs.overlays = [
    (import ./jellyfin-ffmpeg.nix)
    (import ./nushell-plugin-highlight.nix)
  ];
}
