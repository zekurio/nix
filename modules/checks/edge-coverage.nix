{
  config,
  lib,
  inputs,
  ...
}: {
  # `pkgs` is imported here for the same reason flake.nix does it: the flake's
  # nixpkgs input is named nixpkgs-unstable, so flake-parts cannot supply it.
  perSystem = {system, ...}: let
    pkgs = import inputs.nixpkgs-unstable {inherit system;};
  in {
    # Once the router stops forwarding 80/443, a Caddy virtual host without a
    # matching edge route is simply unreachable, and nothing says so until
    # someone tries to use it.
    checks.edge-coverage = let
      uncoveredFor = hostName: hostCfg: let
        homelab = hostCfg.config.services.homelab or {};
        newt = homelab.newt or null;
      in
        lib.optionals (newt != null && newt.enable or false) (
          let
            served = lib.unique (
              map (vhost: vhost.domain) (lib.attrValues (homelab.caddy.virtualHosts or {}))
            );
            published = lib.unique (
              (map (resource: resource.domain) (lib.attrValues newt.resources))
              ++ newt.caddyDomains
              ++ newt.localOnlyDomains
            );
          in
            map (
              domain: "${hostName}: ${domain} is served by Caddy but has no edge route (add a newt resource, list it in caddyDomains, or declare it in localOnlyDomains)"
            ) (lib.subtractLists published served)
        );

      problems = lib.flatten (lib.mapAttrsToList uncoveredFor config.flake.nixosConfigurations);
    in
      if problems == []
      then pkgs.runCommand "edge-coverage-ok" {} "touch $out"
      else
        pkgs.runCommand "edge-coverage-failed" {} ''
          echo "virtual hosts without a route through the edge:" >&2
          ${lib.concatMapStringsSep "\n" (problem: "echo '  - ${problem}' >&2") problems}
          exit 1
        '';
  };
}
