# Repository guidance

## Structure

- `import-tree` discovers every `.nix` file under `modules/` as a flake-parts
  module. No import list is needed. `flake.nix` wires inputs, systems, and the
  formatter.
- Files contribute to shared aggregates under `flake.modules`: `nixos.base`,
  `nixos.adam`, `nixos.lilith`, `nixos.homelab`, `darwin.base`,
  `darwin.sachiel`, and `homeManager.zekurio`. The module system merges contributions.
- `modules/hosts/<host>/` configures one host. `modules/nixos/` and
  `modules/darwin/` hold each platform's base, `modules/nix/` and
  `modules/nixpkgs/` cover both platforms, `modules/homelab/` holds the homelab
  services, and `modules/home/zekurio/` the Home Manager profile.
- Host entrypoints at `modules/hosts/<host>/system.nix` only assemble aggregates.
  Put configuration in focused modules named after their concern, one concern
  per file. Never add a catch-all such as `configuration.nix`.
- Never import module files by relative path. Define shared values in a module
  for all consumers, as in `modules/nix/default.nix`. Relative paths are allowed
  for `_`-prefixed package expressions used with `callPackage`; `import-tree`
  ignores these files.
- Take `inputs` from the flake-parts module arguments. Never pass it down
  through `specialArgs` or `extraSpecialArgs`.
- Import third-party modules in the file that configures them.
- Service options use `services.homelab.<name>`; shared host features use
  `modules.*`. Follow neighbouring modules.

## Nix conventions

- Never nest `imports` to control merge order. Use `lib.mkBefore`, `lib.mkAfter`,
  or `lib.mkDefault` where appropriate and explain why.
- Comment non-obvious constraints and surprising behavior, not assignments.
- Keep substituters in sync in `flake.nix`'s static `nixConfig` and
  `modules/nix/default.nix`.
- Declare service exposure in the service module through
  `services.homelab.caddy.virtualHosts.<name>`. Vhosts are private by default;
  set `public = true` deliberately. Private services sharing a public domain
  restrict their paths with an `@blocked` matcher in `extraConfig`.

## Secrets

- Edit `secrets/<host>.yaml` only through `sops`; never read or write plaintext
  under `secrets/`. Host age recipients are defined in `.sops.yaml`.
- Name credentials after their owner, for example `radarr_api_key`, and declare
  each secret in the module that consumes it.
- Use raw values for shared credentials or options expecting a value file,
  `<service>_env` for one service's `EnvironmentFile`, and `sops.templates`
  to compose secrets into env or config files.
- Nix secret names must match YAML keys. Rename keys and references together;
  never hide renames with `key = "..."`.

## Validation and Git

- Stage new or renamed files before evaluation; flakes only see tracked files.
- Run `nix fmt` and `nix flake check` before completing code changes.
  Build a host only when the changes warrant it.
- Do not update flake inputs unless required by the task.
- Diff against `main` or `origin/main`.
- Branch names use at most three hyphen-separated words, without slashes or
  type prefixes.
- Commits and PR titles use `type(scope): summary`, with optional scope.
  Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`.
