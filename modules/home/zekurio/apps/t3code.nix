{inputs, ...}: {
  perSystem = {system, ...}: let
    pkgs = import inputs.nixpkgs-unstable {inherit system;};
    upstream = inputs.t3code-nightly.packages.${system};
    agents = inputs.llm-agents.packages.${system};
    # GUI launches and systemd services do not inherit the interactive shell PATH.
    extraRuntimePackages = [
      pkgs.git
      pkgs.gh
      pkgs.openssh
      agents.claude-code
      agents.codex
      agents.opencode
    ];
  in {
    packages = pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      t3code = upstream.t3code.override {inherit extraRuntimePackages;};
      t3code-desktop = upstream.t3code-desktop.override {inherit extraRuntimePackages;};
    };
  };

  flake.modules.nixos = {
    base = {pkgs, ...}: {
      home-manager.users.zekurio.home.packages = [
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.t3code
      ];
    };

    lilith = {pkgs, ...}: {
      home-manager.users.zekurio.home.packages = [
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.t3code-desktop
      ];
    };
  };
}
