inputs: _: prev:
let
  unstablePkgs = import inputs.nixpkgs-unstable {
    system = prev.stdenv.hostPlatform.system;
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "electron-36.9.5"
      ];
    };
  };
in
{
  unstable = unstablePkgs;
}
