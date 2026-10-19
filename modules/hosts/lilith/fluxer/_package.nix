{
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  autoPatchelfHook,
  cairo,
  copyDesktopItems,
  cups,
  dbus,
  expat,
  fetchurl,
  glib,
  gtk3,
  lib,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libpulseaudio,
  libsecret,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  libxshmfence,
  makeDesktopItem,
  makeWrapper,
  nspr,
  nss,
  pango,
  pipewire,
  stdenv,
  systemd,
  wayland,
}: let
  # CI rewrites this file whenever upstream tags a new stable desktop build.
  source = lib.importJSON ./_source.json;
  # Electron names its window after package.json's desktopName, so the
  # desktop entry must carry the same ID for docks to group the window.
  desktopId = "app.fluxer.FluxerDesktop";
in
  stdenv.mkDerivation {
    pname = "fluxer-desktop";
    inherit (source) version;

    src = fetchurl {
      url = "https://github.com/fluxerapp/fluxer/releases/download/fluxer-desktop-stable%40${source.version}/Fluxer-${source.version}-linux-x64.tar.gz";
      inherit (source) hash;
    };

    nativeBuildInputs = [
      autoPatchelfHook
      copyDesktopItems
      makeWrapper
    ];

    buildInputs = [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      cairo
      cups
      dbus
      expat
      glib
      gtk3
      libdrm
      libgbm
      libx11
      libxcb
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxkbcommon
      libxrandr
      nspr
      nss
      pango
      pipewire
      stdenv.cc.cc.lib
      systemd
    ];

    # Chromium dlopens these, so they never appear as DT_NEEDED entries.
    runtimeDependencies = [
      libGL
      libnotify
      libpulseaudio
      libsecret
      libxshmfence
      pipewire
      systemd
      wayland
    ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/opt" "$out/bin"
      cp -R . "$out/opt/fluxer"

      # Chromium falls back to the user namespace sandbox when the setuid
      # helper is missing, and the store cannot hold a setuid binary.
      rm "$out/opt/fluxer/chrome-sandbox"

      makeWrapper "$out/opt/fluxer/fluxer" "$out/bin/fluxer"

      for size in 16 24 32 48 64 128 256 512; do
        install -Dm644 "resources/icons/''${size}x''${size}.png" \
          "$out/share/icons/hicolor/''${size}x''${size}/apps/fluxer.png"
      done

      runHook postInstall
    '';

    desktopItems = [
      (makeDesktopItem {
        name = desktopId;
        desktopName = "Fluxer";
        genericName = "Instant Messenger";
        comment = "Instant messaging and VoIP";
        exec = "fluxer %U";
        icon = "fluxer";
        categories = ["Network" "InstantMessaging" "Chat"];
        keywords = ["chat" "im" "messaging" "messenger" "voip" "voice" "video" "call"];
        mimeTypes = ["x-scheme-handler/fluxer"];
        startupWMClass = desktopId;
        startupNotify = true;
        singleMainWindow = true;
        actions = {
          open-settings = {
            name = "Open Settings";
            exec = "fluxer --fluxer-task=open-settings %U";
          };
          new-dm = {
            name = "New Direct Message";
            exec = "fluxer --fluxer-task=new-dm %U";
          };
        };
      })
    ];

    meta = {
      description = "Desktop client for the Fluxer chat platform";
      homepage = "https://fluxer.app";
      license = lib.licenses.agpl3Plus;
      mainProgram = "fluxer";
      platforms = ["x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
