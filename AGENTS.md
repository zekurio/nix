# Agent Guidelines for nix-config

## Build & Verification

- **Build**: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
- **Check**: `nix flake check` to verify flake outputs.
- **Apply**: `nixos-rebuild switch --flake .#<host>` (use `--use-remote-sudo` if needed).
- **Test**: No unit tests. Verify by building.

### Available Hosts

| Host | Type | Key Features |
|------|------|--------------|
| `adam` | Homelab server | Podman services, backups, VPN |
| `lilith` | Desktop workstation | Niri, AMD GPU, gaming, secure boot |
| `tabris` | WSL dev environment | Home Manager only, no system services |

## Code Style & Conventions

- **Style**: 2 spaces indent, `camelCase` naming, sorted imports at top.
- **Structure**:
  - `machines/nixos/<host>/`: Host-specific configuration (configuration.nix, disko.nix).
  - `modules/`: Reusable modules (prefer over ad-hoc config).
  - `modules/homelab/`: Self-hosted services (adam only).
  - `modules/profiles/dev.nix`: Developer tools & shell setup.
  - `modules/profiles/desktop/`: Full desktop environment (lilith).
  - `modules/gaming/`, `modules/graphics/`, `modules/virtualization/`: Hardware & feature modules.
  - `secrets/`: Managed via `sops-nix`. NEVER commit plain text.
- **Flake**: Uses `flake-parts`. Update `flake.lock` only when necessary.
- **Safety**: Verify `flake.lock` changes. Use `nix repl` to inspect.
- **Formatting**: Mimic existing code. Align lists/attrs.

## Workflow

- **Plan**: Analyze `flake.nix` and imports first.
- **Edit**: Use `read` to verify file content before editing.
- **Verify**: Run build command after changes.