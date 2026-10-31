# Nix daemon settings shared by every platform.
{
  inputs,
  lib,
  ...
}: let
  # flake.nix's nixConfig must be a literal, so the caches are listed there
  # once and read back here; the daemon trusts them for every build, not
  # just for this flake.
  inherit (import "${inputs.self}/flake.nix") nixConfig;
in {
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    substituters = ["https://cache.nixos.org/"] ++ nixConfig.extra-substituters;
    # Both platforms add cache.nixos.org's key at the same priority; mkBefore
    # keeps our entries first in /etc/nix/nix.conf.
    trusted-public-keys = lib.mkBefore nixConfig.extra-trusted-public-keys;
  };

  # Hosts that keep generations for a different time override these.
  nix.gc = {
    automatic = lib.mkDefault true;
    options = lib.mkDefault "--delete-older-than 7d";
  };
}
