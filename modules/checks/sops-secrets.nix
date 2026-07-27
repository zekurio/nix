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
    # Every sops.secrets entry must resolve to a key that actually exists in the
    # host's sops file. Key names are plaintext in a sops file, so this needs no
    # decryption and no age key — it only compares names.
    checks.sops-secret-names = let
      # Top-level YAML keys of a sops file, minus sops' own metadata block.
      keysOf = file: let
        lines = lib.splitString "\n" (builtins.readFile file);
        isTopLevelKey = line: builtins.match "^[A-Za-z0-9_]+:.*" line != null;
        nameOf = line: builtins.head (lib.splitString ":" line);
      in
        lib.filter (name: name != "sops") (map nameOf (lib.filter isTopLevelKey lines));

      # sops-nix defaults a secret's `key` to its attribute name and its
      # `sopsFile` to the host's defaultSopsFile.
      missingFor = hostName: hostCfg: let
        secrets = hostCfg.config.sops.secrets or {};
        missing =
          lib.filterAttrs (
            _: secret: !(lib.elem secret.key (keysOf secret.sopsFile))
          )
          secrets;
      in
        lib.mapAttrsToList (
          name: secret: "${hostName}: sops.secrets.${name} wants key '${secret.key}', absent from ${baseNameOf secret.sopsFile}"
        )
        missing;

      problems = lib.flatten (lib.mapAttrsToList missingFor config.flake.nixosConfigurations);
    in
      if problems == []
      then pkgs.runCommand "sops-secret-names-ok" {} "touch $out"
      else
        pkgs.runCommand "sops-secret-names-failed" {} ''
          echo "sops secret names do not match the sops files:" >&2
          ${lib.concatMapStringsSep "\n" (problem: "echo '  - ${problem}' >&2") problems}
          exit 1
        '';
  };
}
