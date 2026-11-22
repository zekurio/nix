{
  lib,
  pkgs,
  ...
}: let
  # venmic's prebuilt addon keeps .init and .plt in the first page, right
  # after the ELF headers. patchelf 0.15.2 grows the headers to add the
  # RUNPATH, moves both sections into a non-executable segment, and leaves
  # DT_INIT pointing at the old offset, so Legcord segfaults when it loads
  # venmic to capture audio as a stream starts. patchelf 0.19 keeps them in
  # place. Listed first, it shadows stdenv's patchelf for both autoPatchelf
  # runs.
  legcord =
    lib.warnIf (pkgs.patchelf.version != "0.15.2")
    "modules/hosts/lilith/legcord.nix: stdenv's patchelf is now ${pkgs.patchelf.version}; if Legcord streams without it, delete this file and add pkgs.legcord back to modules/hosts/lilith/apps.nix."
    (pkgs.legcord.overrideAttrs (old: {
      nativeBuildInputs = [pkgs.patchelfUnstable] ++ old.nativeBuildInputs;
    }));
in {
  environment.systemPackages = [legcord];
}
