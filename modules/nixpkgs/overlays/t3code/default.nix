{
  inputs,
  lib,
  ...
}: let
  overlay = final: previous: let
    t3code-unwrapped = final.callPackage ./_t3code/unwrapped.nix {};
  in {
    inherit t3code-unwrapped;
    t3code = previous.t3code.override {inherit t3code-unwrapped;};
  };
in {
  # Adam is the only Nix host that runs T3 Code. Sachiel keeps using the
  # self-updating Homebrew desktop app, so a T3 bump never builds on the Mac.
  flake.modules.nixos.base.nixpkgs.overlays = [overlay];

  perSystem = {system, ...}: let
    pkgs = import inputs.nixpkgs-unstable {
      inherit system;
      overlays = [overlay];
    };
    t3code = pkgs.t3code.override {
      enableCodex = false;
      enableGit = false;
      enableGitHub = false;
    };
    updateT3code = pkgs.writeShellApplication {
      name = "update-t3code";
      runtimeInputs = [pkgs.nix-update];
      text = ''
        exec nix-update t3code --flake --use-github-releases "$@"
      '';
    };
  in {
    # Exposing the overlaid derivation gives nix-update a stable flake attr and
    # lets Adam validate only T3 with `nix build .#t3code`.
    packages = {
      inherit t3code;
      update-t3code = updateT3code;
    };
    apps.update-t3code = {
      type = "app";
      program = lib.getExe updateT3code;
      meta.description = "Update the pinned stable T3 Code package";
    };
  };
}
