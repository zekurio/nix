inputs: _: prev: {
  quickshell = inputs.quickshell.packages.${prev.stdenv.hostPlatform.system}.default;
}
