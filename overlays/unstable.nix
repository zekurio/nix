inputs: final: prev:
let
  unstablePkgs = import inputs.nixpkgs-unstable {
    system = prev.system;
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
