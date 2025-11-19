# Agent Guidelines for nix-config

## Build & Verification
- **Build**: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
- **Check**: `nix flake check` to verify flake outputs.
- **Apply**: `nixos-rebuild switch --flake .#<host>` (use `--use-remote-sudo` if needed).
- **Test**: No unit tests. Verify by building.

## Code Style & Conventions
- **Style**: 2 spaces indent, `camelCase` naming, sorted imports at top.
- **Structure**:
  - `machines/<os>/<host>`: Host-specific configuration.
  - `modules/`: Reusable modules (prefer over ad-hoc config).
  - `secrets/`: Managed via `sops-nix`. NEVER commit plain text.
- **Flake**: Uses `flake-parts`. Update `flake.lock` only when necessary.
- **Safety**: Verify `flake.lock` changes. Use `nix repl` to inspect.
- **Formatting**: Mimic existing code. Align lists/attrs.

## Workflow
- **Plan**: Analyze `flake.nix` and imports first.
- **Edit**: Use `read` to verify file content before editing.
- **Verify**: Run build command after changes.
