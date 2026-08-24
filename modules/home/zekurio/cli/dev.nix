{
  flake.modules.homeManager.zekurio = {
    programs.direnv = {
      enable = true;
      enableFishIntegration = true;
      nix-direnv.enable = true;
    };
  };
}
