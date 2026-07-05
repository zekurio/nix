{pkgs, ...}: {
  environment.systemPackages = [
    pkgs.feishin
    pkgs.ghostty
    pkgs.zed-editor
  ];
}
