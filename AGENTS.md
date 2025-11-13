# Repository Guidelines

## Project Structure & Module Organization
Configuration is split by host under `machines/nixos/<host>`, with each directory providing `configuration.nix`, optional `disko.nix`, and host-specific overrides. Shared NixOS modules live in `modules/homelab` (self-hosted services, Podman wrappers) and `modules/profiles/workstation.nix` (combined desktop + Home Manager profile). Reusable overlays sit in `overlays`, while secrets encrypted via SOPS are tracked in `secrets/*.yaml`. Flake entry points and inputs are managed in `flake.nix`; keep machine-specific logic out of this file. Most systems follow the stable `nixpkgs` channel, but `lilith` intentionally targets `nixpkgs-unstable` to keep its desktop stack consistent.

## Build, Test, and Development Commands
- `nix flake check` — run flake audits and ensure imports, options, and formatter hooks are valid.
- `nixos-rebuild build --flake .#adam` — materialize the Adam system closure for inspection without switching.
- `nixos-rebuild switch --flake .#tabris` — apply changes to the WSL host; use `--target-host` when deploying remotely.
- `nix build .#nixosConfigurations.tabris.config.system.build.tarball` — build the WSL tarball export described in `README.md`.
- `nix shell nixpkgs#git nixpkgs#nixos-rebuild -c $SHELL` — obtain Git and NixOS deployment tools inside minimal environments such as the NixOS installer ISO.

## Coding Style & Naming Conventions
Use two-space indentation and trailing commas in Nix attribute sets. Group related options with block comments and keep lists (imports, packages) sorted by path or service name. Attribute names follow lowerCamelCase (e.g., `auto-optimise-store`). Prefer module-level helpers (see `modules/homelab/*.nix`) over ad-hoc inline definitions. Format patches with `nix run nixpkgs#nixpkgs-fmt -- *.nix` before committing.

## Testing Guidelines
Validate every change with `nix flake check`. For host-specific updates, run `nixos-rebuild test --flake .#<host>` on a staging machine to simulate activation without switching. Container modules should expose health probes; verify they start cleanly via `systemctl status <service>` after rebuild. When touching secrets, ensure `sops updatekeys secrets/<file>.yaml` is run and decrypted values stay out of the git diff.

## Commit & Pull Request Guidelines
Write concise, imperative commit subjects that mention the focus area (e.g., `adam: enable vaultwarden backups`). Squash incidental formatting changes into the functional commit. Pull requests should outline the intent, affected hosts, deployment steps, and any required secrets or follow-up tasks. Link related issues when available and add `journalctl -u <service>` excerpts or screenshots if service behavior changes.

## Secrets & Configuration Tips
SOPS files in `secrets/` are managed by `sops-nix`; keep the age key location consistent with `configuration.nix`. When provisioning a new host, duplicate an existing machine folder, adjust hardware imports, and register the host in `flake.nix`. Avoid storing plaintext credentials— use environment files or systemd secret support exposed by the modules.
