{pkgs, ...}: {
  nixpkgs.config.permittedInsecurePackages = [
    # Required by Electron desktop apps until nixpkgs updates their runtime.
    "electron-39.8.10"
  ];

  environment.systemPackages = [
    pkgs.bitwarden-desktop
    pkgs.feishin
    pkgs.ghostty
    pkgs.zed-editor
  ];
}
