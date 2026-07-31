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
    updateExtras = pkgs.writeShellApplication {
      name = "update-extras";
      runtimeInputs = [pkgs.nix-update];
      text = ''
        # Add future repo-pinned, fast-moving packages here and in the case
        # statement below. Runtime-profile agents intentionally stay separate.
        registered=(
          t3code
        )

        usage() {
          echo "Usage: update-extras [--list | TARGET...]"
          echo
          echo "With no targets, update every registered extra."
        }

        if [[ "$#" -eq 1 ]]; then
          case "$1" in
            --list)
              printf '%s\n' "''${registered[@]}"
              exit 0
              ;;
            --help | -h)
              usage
              exit 0
              ;;
          esac
        fi

        if [[ "$#" -eq 0 ]]; then
          set -- "''${registered[@]}"
        fi

        for target in "$@"; do
          case "$target" in
            t3code)
              nix-update t3code --flake --use-github-releases
              ;;
            *)
              echo "Unknown extra: $target" >&2
              echo "Registered extras:" >&2
              printf '  %s\n' "''${registered[@]}" >&2
              exit 2
              ;;
          esac
        done
      '';
    };
  in {
    # Exposing the overlaid derivation gives nix-update a stable flake attr and
    # lets Adam validate only T3 with `nix build .#t3code`.
    packages = {
      inherit t3code;
      update-extras = updateExtras;
    };
    apps.update-extras = {
      type = "app";
      program = lib.getExe updateExtras;
      meta.description = "Update fast-moving packages maintained outside nixpkgs";
    };
  };
}
