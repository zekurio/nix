{inputs, ...}: {
  perSystem = {system, ...}: let
    pkgs = import inputs.nixpkgs-unstable {inherit system;};
  in {
    # cache.numtide.com only holds llm-agents packages built against the
    # nixpkgs revision llm-agents locks itself. `nix flake update` (the weekly
    # PR) re-resolves that transitive input to the nixpkgs tip, after which
    # Codex is a long Rust build on every host. Re-pin with:
    #   nix flake lock --override-input llm-agents/nixpkgs github:NixOS/nixpkgs/<rev>
    checks.llm-agents-nixpkgs-pin = let
      wanted = (builtins.fromJSON (builtins.readFile "${inputs.llm-agents}/flake.lock")).nodes.nixpkgs.locked.rev;
      actual = inputs.llm-agents.inputs.nixpkgs.rev;
    in
      if wanted == actual
      then pkgs.runCommand "llm-agents-nixpkgs-pin-ok" {} "touch $out"
      else
        pkgs.runCommand "llm-agents-nixpkgs-pin-failed" {} ''
          echo "llm-agents/nixpkgs is ${actual}, but llm-agents locks ${wanted};" >&2
          echo "cache.numtide.com will miss. Re-pin:" >&2
          echo "  nix flake lock --override-input llm-agents/nixpkgs github:NixOS/nixpkgs/${wanted}" >&2
          exit 1
        '';
  };
}
