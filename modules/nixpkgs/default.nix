{
  imports = [
    ./overlays/jellyfin
  ];

  nixpkgs.config = {
    allowUnfree = true;
  };
}
