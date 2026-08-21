{inputs, ...}: {
  flake.modules.nixos.lilith = {pkgs, ...}: let
    system = pkgs.stdenv.hostPlatform.system;
  in {
    environment.systemPackages = [
      inputs.llm-agents.packages.${system}.chatgpt
    ];
  };
}
