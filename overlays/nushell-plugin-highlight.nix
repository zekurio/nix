final: prev: {
  nushellPlugins = prev.nushellPlugins // {
    highlight = final.callPackage ./packages/nushell-plugin-highlight.nix { };
  };
}
