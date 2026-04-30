# Repository Guidelines

## Project Structure & Module Organization
This repository is a Nix flake built around `flake-parts`. Keep shared flake wiring in [`flake.nix`](/home/zekurio/nix/flake.nix), and put host or feature logic in modules imported from the nearest owning directory instead of expanding the root flake inline.

- `modules/hosts/`: host-specific NixOS systems such as `adam/`
- `modules/hosts/_common/`: shared host defaults
- `modules/homelab/`: reusable homelab services; most services live under `modules/homelab/services/<service>/default.nix`
- `modules/users/zekurio/`: Home Manager user profile split by concern (`packages.nix`, `shell.nix`, `gitconfig.nix`, etc.)
- `modules/nixpkgs/overlays/`: package overrides and overlays
- `secrets/`: SOPS-encrypted host secrets

Prefer adding new functionality as a focused module with a `default.nix`. Follow the existing pattern: `flake.nix` imports `modules/hosts/`, hosts assemble module lists, and services or user concerns stay isolated in submodules.

## Build, Test, and Development Commands
- `nix fmt`: format the repository with the flake formatter (`alejandra`)
- `nix flake check`: validate flake evaluation and standard checks
- `nix build .#nixosConfigurations.adam.config.system.build.toplevel`: build the `adam` system without switching
- `nix flake update`: refresh inputs; CI’s scheduled workflow commits `flake.lock` updates automatically

## Coding Style & Naming Conventions
Use `nix fmt`; do not hand-format around it. Keep modules small and composable. Name directories and files after the host, service, or concern they define, for example `modules/homelab/services/seerr/default.nix`. Use lowercase attribute names and keep options close to the service or host they configure.

## Testing Guidelines
There is no standalone unit test suite in this repo. Minimum validation for changes is:

- `nix fmt`
- `nix flake check`
- a targeted `nix build` for each affected host

When changing encrypted inputs or service environment files, verify the relevant SOPS secret paths still resolve.

## Secrets & Configuration Safety
Never edit files under `secrets/` directly as plaintext. Never EVER modify SOPS-managed secret files without using `sops`, for example `sops secrets/adam.yaml`. Changes that bypass SOPS metadata will break decryption and deployment.

## Commit & Pull Request Guidelines
Recent history mixes short fixes (`fix DNS`, `fix beets`) with conventional commits (`feat(adam): ...`, `chore: update flake.lock`). Prefer imperative, scoped subjects such as `feat(adam): enable service` or `fix(adam): correct DNS`. Keep commits focused.

PRs should describe the affected host or module, the rebuild command used, and any secret or migration impact. Include logs or screenshots only when the change affects visible behavior or deployment output.
