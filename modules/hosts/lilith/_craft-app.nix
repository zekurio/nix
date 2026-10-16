{
  alsa-lib,
  autoPatchelfHook,
  dbus,
  fetchurl,
  lib,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  libxkbcommon,
  libxrandr,
  stdenv,
  vulkan-loader,
  wayland,
  # Per-app release details.
  pname,
  version,
  hash,
  description,
}:
stdenv.mkDerivation {
  inherit pname version;

  # Upstream's release tarball already carries the desktop entry, icons and
  # MIME types, which a source build would have to recreate.
  src = fetchurl {
    url = "https://github.com/storytold/${pname}/releases/download/v${version}/${pname}-${version}-linux-x86_64.tar.gz";
    inherit hash;
  };

  nativeBuildInputs = [autoPatchelfHook];
  # DeckCraft links ALSA for slide audio; the other apps ignore it.
  buildInputs = [
    alsa-lib
    stdenv.cc.cc.lib
  ];
  # winit, wgpu and rfd dlopen these, so they never show up as DT_NEEDED and
  # autoPatchelf only adds them to the rpath through runtimeDependencies.
  # DeckCraft opens its window through X11 even in a Wayland session.
  runtimeDependencies = [
    dbus
    libx11
    libxcb
    libxcursor
    libxi
    libxkbcommon
    libxrandr
    vulkan-loader
    wayland
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R bin share "$out/"
    runHook postInstall
  '';

  meta = {
    inherit description;
    homepage = "https://github.com/storytold/${pname}";
    license = with lib.licenses; [mit asl20];
    mainProgram = pname;
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
}
