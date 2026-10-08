{inputs, ...}: {
  flake.modules.darwin.base = {config, ...}: {
    imports = [inputs.nix-homebrew.darwinModules.nix-homebrew];

    nix-homebrew = {
      enable = true;
      autoMigrate = true;
      enableFishIntegration = true;
      user = config.system.primaryUser;
    };
  };
}
