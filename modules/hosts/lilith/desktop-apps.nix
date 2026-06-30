{
  inputs,
  pkgs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
in {
  environment.systemPackages = [
    inputs.nix-t3code.packages.${system}.t3code-nightly
    pkgs.feishin
    pkgs.ghostty
    pkgs.zed-editor
  ];
}
