# Each platform's user module imports its own Home Manager module.
{inputs, ...}: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {inherit inputs;};

    users.zekurio.imports = [inputs.self.homeModules.zekurio];
  };
}
