{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    openssh
    python3
    uv
  ];
}
