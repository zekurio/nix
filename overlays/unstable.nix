inputs:
final: prev:
let
  unstablePkgs = import inputs.nixpkgs-unstable {
    system = prev.system;
    config.allowUnfree = true;
  };
in
{
  unstable = unstablePkgs;
  quickshell = unstablePkgs.quickshell;
}
