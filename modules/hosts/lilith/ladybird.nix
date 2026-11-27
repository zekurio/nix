{
  lib,
  pkgs,
  ...
}: let
  # nixpkgs packages a snapshot from before the first alpha release. Build
  # the alpha tag until nixpkgs catches up.
  upstream = pkgs.ladybird;
  version = "2026.47.7";
  src = pkgs.fetchFromGitHub {
    owner = "LadybirdBrowser";
    repo = "ladybird";
    tag = version;
    hash = "sha256-ZSJ6QjGA7MAR/8joe0NwkhJyWZw/ag4tOCd0+F7siAA=";
  };
  # The alpha's Vulkan video decoder sets a hwaccel flag that only exists in
  # Ladybird's vendored FFmpeg. Apply its two Vulkan decode patches to
  # nixpkgs' FFmpeg, which is the same 9.0.2 release; the others only adapt
  # the vcpkg build.
  ffmpeg = pkgs.ffmpeg.overrideAttrs (prev: {
    patches =
      prev.patches
      ++ map (name: "${src}/Meta/CMake/vcpkg/overlay-ports/ffmpeg/${name}") [
        "0101-vulkan-decode-dpb-distinct-no-drm-modifiers.patch"
        "0102-vulkan-av1-clear-unused-ref-frame-mvs.patch"
      ];
  });
  # The alpha uses LLVM libc's header-only math functions, pinned to the
  # llvm-project commit in Meta/CMake/vcpkg/overlay-ports/llvm-libc. AK and
  # the Rust crates include them as llvm-libc/<path under libc/>.
  llvmLibc = pkgs.linkFarm "llvm-libc-headers" [
    {
      name = "llvm-libc";
      path = "${pkgs.fetchFromGitHub {
        owner = "llvm";
        repo = "llvm-project";
        rev = "e54169423e7ee5d8b41c2f1b6f7a59000c901ee0";
        sparseCheckout = ["libc"];
        hash = "sha256-rYvY2rTNwA3Ovy3y/hI3nTp9v8kJbhxB2gseLcZ5vWA=";
      }}/libc";
    }
  ];
  ladybird =
    lib.warnIf (upstream.version != "0-unstable-2026-11-01")
    "modules/hosts/lilith/ladybird.nix: nixpkgs' Ladybird is now ${upstream.version}; delete the source override if it includes the 2026.47.7 alpha."
    ((upstream.override {inherit ffmpeg;}).overrideAttrs (finalAttrs: prev: {
      inherit version src;
      cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) pname version src;
        hash = "sha256-fYqoQxHodl7DJMfjp3S000CF8kFSD996LTH3dKg7Dtw=";
      };
      # The alpha finds PDF.js through FindPDFJS.cmake instead of reading
      # vcpkg's directory in ResourceFiles.cmake, so nixpkgs' substitution
      # there no longer matches. Keep its patched copy and point
      # FindPDFJS's cache variable at it.
      postPatch =
        builtins.replaceStrings [
          ''
            substituteInPlace UI/cmake/ResourceFiles.cmake \
              --replace-fail 'if (NOT "''${VCPKG_INSTALLED_DIR}" STREQUAL "" AND NOT "''${VCPKG_TARGET_TRIPLET}" STREQUAL "")' 'if (TRUE)' \
              --replace-fail '"''${VCPKG_INSTALLED_DIR}/''${VCPKG_TARGET_TRIPLET}/share/pdfjs"' '"''${LADYBIRD_SOURCE_DIR}/pdfjs"'
          ''
        ] [""]
        prev.postPatch;
      cmakeFlags = prev.cmakeFlags ++ ["-DLLVM_LIBC_INCLUDE_DIR=${llvmLibc}"];
      preConfigure =
        prev.preConfigure
        + ''
          cmakeFlagsArray+=("-DPDFJS_DIR=$PWD/pdfjs")
        '';
    }));
in {
  environment.systemPackages = [ladybird];
}
