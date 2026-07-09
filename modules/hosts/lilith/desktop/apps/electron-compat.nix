{
  nixpkgs.config.permittedInsecurePackages = [
    # Required by Electron desktop apps until nixpkgs updates their runtime.
    "electron-39.8.10"
  ];
}
