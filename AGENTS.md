# Agent Guidelines for nix-config

## Build & Verification
- **Build System**: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
- **Validate**: `nix flake check` to verify flake outputs and inputs.
- **Apply**: `nixos-rebuild switch --flake .#<host>` (use `--use-remote-sudo` if needed).
- **Test**: No unit tests. Verification is done by building the configuration.

## Code Style & Conventions
- **Indentation**: 2 spaces. No tabs.
- **Naming**: `camelCase` for variables and attributes.
- **Imports**: Keep imports at the top. Use relative paths.
- **Secrets**: Managed via `sops-nix`. NEVER commit plain text secrets.
- **Structure**:
  - `machines/<os>/<host>`: Host-specific configs.
  - `modules/`: Shared modules. Prefer creating modules for reusable components.
- **Formatting**: Follow existing file patterns. Align lists and attribute sets.
- **Safety**: Always check `flake.lock` changes before committing.
