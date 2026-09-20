{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    # Keep these sources aligned with the scanner image in default.nix.
    provider = name: hash: patch:
      pkgs.runCommand "kyoo-${name}-artwork" {
        src = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/zoriya/kyoo/v5.2.1/scanner/scanner/providers/${name}.py";
          inherit hash;
        };
        nativeBuildInputs = [pkgs.patch];
      } ''
        cp "$src" ${name}.py
        chmod u+w ${name}.py
        patch -p1 < ${patch}
        cp ${name}.py "$out"
      '';
    tvdb = provider "thetvdb" "sha256-kTdKTuJ+UFH1n1RW1l2qfXTk+BFgPMmawZGs7H9gQWA=" ./thetvdb-artwork.patch;
    tmdb = provider "themoviedatabase" "sha256-QYIJkJi8pUOdn/dT6rCgL2l7rj67FImOh+baapikPm0=" ./themoviedatabase-artwork.patch;
  in {
    config = lib.mkIf config.services.homelab.kyoo.enable {
      # Use English or other available artwork when localized/textless art is absent.
      virtualisation.oci-containers.containers.kyoo-scanner.volumes = [
        "${tvdb}:/app/scanner/providers/thetvdb.py:ro"
        "${tmdb}:/app/scanner/providers/themoviedatabase.py:ro"
      ];
    };
  };
}
