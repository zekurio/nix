{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    macmon
    openssh
    python3
    rustup
    uv
    yubikey-manager
  ];
}
