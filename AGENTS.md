# Repository guidance

## Structure

- Every `.nix` file under a directory of `modules/` is a module of the class
  that directory serves: NixOS, nix-darwin, or Home Manager. `flake.nix`
  imports the directories with `import-tree`, so there are no import lists.
  `flake.nix` wires inputs, hosts, packages, and the formatter; `packages/`
  holds the package outputs.
- `modules/common/` holds modules shared by NixOS and nix-darwin; use only
  options both platforms define there. `modules/nixos/` and `modules/darwin/`
  hold each platform's base, `modules/homelab/` the homelab services that only
  `adam` imports, `modules/hosts/<host>/` one host, and `modules/home/zekurio/`
  the Home Manager profile, exported as `homeModules.zekurio`.
- Put configuration in focused modules named after their concern, one concern
  per file. Never add a catch-all such as `configuration.nix`.
- `inputs` is a module argument in every class. `flake.nix` passes it through
  `specialArgs` and the user modules through `extraSpecialArgs`; take it from
  the module arguments and nowhere else.
- Never import module files by relative path. Define shared values as options
  that every consumer reads, as in `modules/homelab/domains.nix`. Relative
  paths are allowed for `_`-prefixed package expressions used with
  `callPackage`; `import-tree` ignores these files.
- Import third-party modules in the file that configures them.
- Service options use `services.homelab.<name>`; shared host features use
  `modules.*`. Follow neighbouring modules.

## Nix conventions

- Never nest `imports` to control merge order. Use `lib.mkBefore`, `lib.mkAfter`,
  or `lib.mkDefault` where appropriate and explain why.
- Comment non-obvious constraints and surprising behavior, not assignments.
- Never add a README that describes what a module does. Comments next to the
  code carry that. `README.md` only lists manual procedures such as bootstrap,
  rebuilds, and recovery.
- Keep substituters in sync in `flake.nix`'s static `nixConfig` and
  `modules/common/nix.nix`.
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
