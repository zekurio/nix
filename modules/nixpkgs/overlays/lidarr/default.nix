# Lidarr's plugin system — the System → Plugins page and the loader that lets a
# plugin register a first-party download client — does not exist on master,
# which is what nixpkgs packages. Without it Soulseek can only ever be bridged
# by an external script; with it, slskd appears as a real download client and
# indexer directly in Lidarr.
#
# Target: tag v3.1.3.4975 on the develop line, which is where upstream merged
# plugin support. Two constraints pin it there rather than anywhere else:
#
#   * Lidarr filters plugin releases by `net{runtime major}.0` and by a
#     "Minimum Lidarr Version" line it parses out of the GitHub release body,
#     comparing it against BuildInfo.Version.
#   * The maintained slskd plugin (TypNull/Tubifarry) ships net8.0 assets and
#     declares a minimum of 3.1.3.0.
#
# So the long-lived `plugins` branch is a dead end: upstream's CI publishes it
# as 3.1.2.4913 (last built 2026-01-18), which is below that minimum, and the
# one dedicated slskd plugin still targeting it only releases net6.0 assets.
# v3.1.3.4975 is net8.0, carries the loader and the Plugins UI, and satisfies
# the minimum.
#
# The expression is vendored rather than overridden because buildDotnetModule
# strips `nugetDeps` before mkDerivation, and the develop line bumps ~26 NuGet
# packages, so the lockfile has to be replaced rather than patched. Regenerate
# it on a linux host after any bump:
#
#   nix build .#nixosConfigurations.adam.pkgs.lidarr.fetch-deps
#   ./result modules/nixpkgs/overlays/lidarr/_lidarr/deps.json
#
# Switching is one-way for the database: the develop line adds migrations that
# master never had, and master cannot read the reshaped tables afterwards. Back
# up /var/lib/lidarr before the first switch.
#
# Drop this directory once nixpkgs ships a Lidarr with plugin support.
let
  overlay = final: _prev: {
    lidarr = final.callPackage ./_lidarr/package.nix {};
  };
in {
  # Only adam runs Lidarr; the darwin base is deliberately untouched.
  flake.modules.nixos.base.nixpkgs.overlays = [overlay];
}
