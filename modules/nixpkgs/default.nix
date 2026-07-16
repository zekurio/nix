{
  flake.modules.nixos.base = {
    nixpkgs.config = {
      allowUnfree = true;
    };
  };

  flake.modules.darwin.base = {
    nixpkgs.config = {
      allowUnfree = true;
    };
  };
}
