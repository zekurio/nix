inputs: _: prev: {
  quickshell = inputs.quickshell.packages.${prev.system}.default;
}
