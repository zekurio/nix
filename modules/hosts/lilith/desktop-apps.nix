{
  inputs,
  pkgs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
in {
  environment.systemPackages = [
    inputs.helium.packages.${system}.default
    inputs.nix-t3code.packages.${system}.t3code-nightly
    inputs.zed.packages.${system}.default
    pkgs.feishin
    pkgs.ghostty
  ];
}
