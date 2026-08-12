{
  flake.modules.homeManager.zekurio = {
    inputs,
    pkgs,
    ...
  }: let
    agentStuff = pkgs.callPackage ./_agent-stuff.nix {} {
      src = inputs.agent-stuff;
    };
  in {
    # Keep the packaged resources available without managing Pi's mutable
    # settings.json; configure and scope models directly from Pi instead.
    home.file.".pi/agent/packages/agent-stuff".source = agentStuff;
  };
}
