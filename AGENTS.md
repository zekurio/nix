# AGENTS.md

This file gives AI agents the repo-specific context they need when working in this Nix configuration repository.

- The default branch in this repo is `main`.
- Use `main` or `origin/main` for diffs.
- Before running Nix evaluation commands such as `nix flake check` or `nix build`, run `git add` for files changed in the task. Nix flakes only see files tracked by Git, so newly created modules must be added to the index before checks or builds.
- Never edit files under `secrets/` directly as plaintext. Never modify SOPS-managed secret files without using `sops`.

## Branch Names

Use a short branch name of at most three words, separated by hyphens. Do not use slashes or type prefixes such as `feat/` or `fix/`.

Examples: `adam-dns`, `service-cleanup`, `update-shell`.

## Commits and PR Titles

Use conventional commit-style messages and PR titles when practical: `type(scope): summary`.

Valid types are `feat`, `fix`, `docs`, `chore`, `refactor`, and `test`. Scopes are optional; use the affected host, module, or concern when helpful, e.g. `adam`, `homelab`, `users`, `overlays`, `secrets`, or `flake`.

Examples: `fix(adam): correct DNS`, `feat(homelab): enable service`, `chore: update flake.lock`.

## Style Guide

### General Principles

- Prefer small, composable modules over expanding root-level files.
- Keep host-specific decisions in host modules and reusable service logic in service modules.
- Keep options close to the service or host they configure.
- Use explicit attribute names and stable module boundaries instead of broad utility files.
- Add comments for non-obvious deployment constraints, host assumptions, or secret wiring. Avoid comments that restate simple assignments.

### Nix Formatting and Organization

- Use `nix fmt`; do not hand-format around the formatter.
- Keep shared flake wiring in `flake.nix`.
- Put host or feature logic in modules imported from the nearest owning directory.
- Prefer adding new functionality as a focused module with a `default.nix`.
- Follow the existing pattern: `flake.nix` imports `modules/hosts/`, hosts assemble module lists, and services or user concerns stay isolated in submodules.
- Name directories and files after the host, service, or concern they define, for example `modules/homelab/services/seerr/default.nix`.
- Use lowercase attribute names unless an upstream option requires a specific case.

### Flake and Module Safety

- Do not rely on untracked files for flake evaluation. Stage new files before checks and builds.
- Keep `flake.lock` changes intentional. Do not update inputs unless the task requires it.
- Do not make broad host rebuild-impacting changes when a service-local module update is enough.
- When changing encrypted inputs or service environment files, verify the relevant SOPS secret paths still resolve.
- Never bypass SOPS metadata. Use `sops secrets/<file>.yaml` for secret edits.

## Testing

There is no standalone unit test suite in this repo. Minimum validation for Nix changes is:

```sh
nix fmt
git add <changed files>
nix flake check
```

Run a targeted host build when the change affects a host, module, package, overlay, or service:

```sh
nix build .#nixosConfigurations.adam.config.system.build.toplevel
```

## Task Completion Requirements

### Nix Tasks

Before considering a Nix task completed, run the relevant commands from the Testing section. Builds should only be issued when warranted by the changed surface.

### Documentation or Planning Tasks

If the task only changes docs or plans, verification can be limited to reading the changed files unless the user asks for more. Still keep examples and commands accurate.

## Project Structure

- `flake.nix` - flake-parts entrypoint and shared flake wiring.
- `modules/hosts/` - host-specific NixOS systems such as `adam/`.
- `modules/hosts/_common/` - shared host defaults.
- `modules/homelab/` - reusable homelab services.
- `modules/homelab/services/<service>/default.nix` - service modules.
- `modules/users/zekurio/` - Home Manager user profile split by concern.
- `modules/nixpkgs/overlays/` - package overrides and overlays.
- `secrets/` - SOPS-encrypted host secrets.

## Project Snapshot

This repository is a Nix flake built around `flake-parts` for NixOS hosts, Home Manager configuration, homelab services, overlays, and encrypted deployment secrets.

## Core Priorities

1. Reproducibility first.
2. Deployment safety first, especially around secrets and host rebuilds.
3. Keep module boundaries predictable and easy to audit.
4. Prefer narrow changes that can be checked or built directly.

If a tradeoff is required, choose correctness, reproducibility, and safe deployment over short-term convenience.

## Maintainability

Long-term maintainability is a core priority. If you add new functionality, first check if there is an existing host, service, user, or overlay module that owns it. Duplicate flake logic across multiple files is a code smell and should be avoided.
