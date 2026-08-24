{inputs, ...}: {
  flake.modules.homeManager.zekurio = {
    imports = [inputs.agent-stuff.homeManagerModules.default];
    programs.agent-stuff.enable = true;
  };
}
