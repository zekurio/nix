{pkgs, ...}: {
  # nixpkgs does not package Fluxer. The client only checks for updates
  # when it runs as an AppImage, and otherwise defers to the package
  # manager, so the update-fluxer-desktop workflow keeps this current.
  environment.systemPackages = [(pkgs.callPackage ./_package.nix {})];
}
