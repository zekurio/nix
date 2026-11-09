{
  nixpkgs.config = {
    allowUnfree = true;
    # androidenv refuses to evaluate without it. Only hosts that set
    # agents.android.enable build an Android SDK.
    android_sdk.accept_license = true;
  };
}
