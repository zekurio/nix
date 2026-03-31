{
  stdenv,
  lib,
  fetchFromGitHub,
  kernel,
  kernelModuleMakeFlags,
}:
stdenv.mkDerivation {
  pname = "nct6687d";
  version = "unstable-2025-12-13-${kernel.version}";

  src = fetchFromGitHub {
    owner = "Fred78290";
    repo = "nct6687d";
    rev = "659aea21c0ca1c85d78cdcaf0a7de9caf103b732";
    hash = "sha256-ivKi4I68Azpzo9eeH4YeEOQmKiG6DQQVJPtCFmUQ7/A=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;

  hardeningDisable = ["pic"];

  makeFlags =
    kernelModuleMakeFlags
    ++ [
      "-C"
      "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      "M=$(PWD)"
    ];

  buildFlags = ["modules"];

  installFlags = ["INSTALL_MOD_PATH=${placeholder "out"}"];
  installTargets = ["modules_install"];

  enableParallelBuilding = true;

  meta = {
    description = "External Linux kernel module for the Nuvoton NCT6687D hardware monitor";
    homepage = "https://github.com/Fred78290/nct6687d";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
  };
}
