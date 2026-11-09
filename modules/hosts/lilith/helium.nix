{
  inputs,
  lib,
  pkgs,
  ...
}: let
  helium = inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default;
in {
  environment.systemPackages = [
    # The flake's wrapper misses two things nixpkgs' wrapGAppsHook would
    # add. Wrapping the finished package avoids re-running autoPatchelf over
    # the whole browser.
    (pkgs.symlinkJoin {
      inherit (helium) name meta;
      paths = [helium];
      nativeBuildInputs = [pkgs.makeWrapper];
      # Chromium dlopens libgtk-3.so.0 for its GTK theme. autoPatchelfHook
      # keeps only DT_NEEDED libraries on the RUNPATH, so the flake's gtk3
      # never reaches the binary, and the GTK theme falls back to stock
      # colours without an error.
      #
      # GTK 3 outside Flatpak reads the theme name from GSettings, not the
      # settings portal. Without the schemas it cannot, and falls back to
      # settings.ini, which never changes while Helium runs. With them it
      # reads DMS's adw-gtk3 or adw-gtk3-dark from dconf and repaints when
      # DMS cycles the name after each theme change. The session's
      # GIO_EXTRA_MODULES already provides the dconf backend.
      postBuild = ''
        rm $out/bin/helium
        makeWrapper ${lib.getExe helium} $out/bin/helium \
          --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [pkgs.gtk3]} \
          --prefix XDG_DATA_DIRS : ${lib.concatMapStringsSep ":" pkgs.glib.getSchemaDataDirPath [pkgs.gsettings-desktop-schemas pkgs.gtk3]}
      '';
    })
  ];
}
