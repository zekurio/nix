{inputs, ...}: {
  flake.modules.nixos.lilith = {pkgs, ...}: let
    system = pkgs.stdenv.hostPlatform.system;
  in {
    environment.systemPackages = [
      inputs.llm-agents-chatgpt.packages.${system}.chatgpt
    ];

    home-manager.users.zekurio.modules.codexRouter.enable = true;
  };
}
