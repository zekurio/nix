inputs:
final: prev:
{
  unstable = import inputs.nixpkgs-unstable {
    system = prev.system;
    config.allowUnfree = true;
  };
}
