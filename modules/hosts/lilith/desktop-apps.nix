{
  inputs,
  pkgs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
in {
  environment.systemPackages = [
    inputs.nix-t3code.packages.${system}.t3code-nightly
    inputs.zed.packages.${system}.default
    pkgs.feishin
    pkgs.ghostty
  ];
}
