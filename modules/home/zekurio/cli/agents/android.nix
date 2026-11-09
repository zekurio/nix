{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.agents.android;

  # Android 16. Pinned instead of following "latest", so a flake.lock bump
  # cannot swap the system image under an existing virtual device.
  platform = "36";
  image = "system-images;android-${platform};google_apis;x86_64";
  avd = "Pixel_9";

  sdk =
    (pkgs.androidenv.composeAndroidPackages {
      # The legacy tools package ships its own avdmanager, which T3 Code
      # reports as an unsupported SDK.
      toolsVersion = null;
      includeCmake = false;
      includeEmulator = true;
      includeSystemImages = true;
      platformVersions = [platform];
      systemImageTypes = ["google_apis"];
      abiVersions = ["x86_64"];
    }).androidsdk;

  # nixpkgs installs the command-line tools under their version number.
  # T3 Code only looks in cmdline-tools/latest, where Android Studio puts
  # them.
  root = pkgs.runCommand "android-sdk-root" {} ''
    mkdir -p $out/cmdline-tools
    for entry in ${sdk}/libexec/android-sdk/*; do
      name=$(basename "$entry")
      if [ "$name" = cmdline-tools ]; then
        ln -s "$entry"/* $out/cmdline-tools/latest
      else
        ln -s "$entry" "$out/$name"
      fi
    done
  '';

  sdkHome = "${config.home.homeDirectory}/Android/Sdk";
in {
  options.agents.android.enable = lib.mkEnableOption "an Android SDK, emulator and virtual device for T3 Code's Device panel";

  config = lib.mkIf cfg.enable {
    # ~/Android/Sdk is where Android Studio installs the SDK and the first
    # place T3 Code looks. Its desktop app copies only a fixed list of
    # variables from the login shell, and ANDROID_HOME is not on it, so the
    # variable alone would not reach it. The SDK is read-only: sdkmanager
    # and Gradle cannot install packages into it.
    home.file."Android/Sdk".source = root;

    # Gradle has no default location and needs the variable.
    home.sessionVariables.ANDROID_HOME = sdkHome;

    # T3 Code lists virtual devices but does not create them. The device
    # stores its system image as a path relative to the SDK, so it survives
    # a new store path. A failure here must not abort the activation of
    # everything else.
    # avdmanager's launcher finds Java with `which` and checks its version
    # with awk. The activation's PATH has neither.
    # The emulator needs /dev/kvm to run this x86_64 image.
    home.activation.androidAvd = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ ! -e "$HOME/.android/avd/${avd}.ini" ]; then
        if ! echo no | run env PATH="${lib.makeBinPath [pkgs.which pkgs.gawk]}:$PATH" \
          ${root}/cmdline-tools/latest/bin/avdmanager create avd \
          --name ${avd} --package ${lib.escapeShellArg image} --device pixel_9 > /dev/null; then
          warnEcho "Could not create the Android virtual device ${avd}; T3 Code will list no emulator."
        fi
      fi
    '';
  };
}
