{inputs, ...}: {
  flake.modules.homeManager.zekurio = {pkgs, ...}: let
    system = pkgs.stdenv.hostPlatform.system;
  in {
    # Agent runtime with a server/client split: panes keep running without an
    # attached terminal. Remote attach from another host rides plain SSH
    # (`herdr --remote adam`), and client and server must speak the same
    # protocol, so herdr comes from the llm-agents input like the agent CLIs —
    # one flake.lock pin guarantees the same version on every host.
    home.packages = [inputs.llm-agents.packages.${system}.herdr];
  };
}
