{
  inputs,
  lib,
  pkgs,
  ...
}: {
  # niri 26.04 has no GlobalShortcuts portal; it landed on main afterwards.
  programs.niri.package =
    lib.warnIf (lib.versionOlder "26.04" pkgs.niri.version)
    "nixpkgs now has niri ${pkgs.niri.version}. If it implements the GlobalShortcuts portal, delete modules/hosts/lilith/niri-main.nix and the niri input in flake.nix."
    inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri;
}
