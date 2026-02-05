# AGENTS.md

This is a NixOS flake configuration repository managing three hosts: `adam` (homelab
server), `tabris` (WSL dev box), and `lilith` (desktop workstation). The entire codebase
is Nix — there are no shell scripts, no traditional test suites, and no CI/CD pipelines.

## Build / Format / Evaluate Commands

```bash
# Format all Nix files (uses alejandra)
nix fmt

# Build a specific host configuration (does NOT activate it)
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
# e.g. nix build .#nixosConfigurations.adam.config.system.build.toplevel

# Evaluate a single host to check for errors (fast, no build)
nix eval .#nixosConfigurations.<host>.config.system.build.toplevel --raw 2>&1 | head -1
# or use --dry-run:
nixos-rebuild dry-build --flake .#<host>

# Apply configuration on the running host
sudo nixos-rebuild switch --flake .#<host>

# Check a single module evaluates correctly (evaluate a specific option)
nix eval .#nixosConfigurations.adam.config.services.jellyfin.enable

# Check flake validity
nix flake check

# Update all flake inputs
nix flake update

# Update a single flake input
nix flake update <input-name>
```

## Repository Structure

```
flake.nix                  # Root flake: inputs, host definitions, outputs
machines/nixos/
  default.nix              # Shared base config imported by all hosts
  adam/                    # Homelab server (ZFS, media stack, Caddy, sops-nix)
  tabris/                  # WSL dev box (NixOS-WSL)
  lilith/                  # Desktop workstation (Niri compositor, AMD GPU)
modules/
  home-manager/            # User-level config (shell.nix always-on, desktop.nix opt-in)
  homelab/services/        # Homelab service modules (one file per service)
  users/                   # User definitions and home-manager bootstrap
  virtualization/          # Rootless Podman setup
overlays/                  # Package overlays (e.g. jellyfin-ffmpeg)
secrets/                   # SOPS-encrypted secrets (age encryption)
```

Every directory has a `default.nix` **aggregator** — it only imports child modules and
contains no logic. Aggregator files use `{...}:` as their argument.

## Code Style

### Formatter

All code must be formatted with **alejandra** (`nix fmt`). Run it before committing.

### Module Structure

Every module follows this exact pattern:

```nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.<option-path>;
  domain = "...";
  port = 1234;
in {
  options.<option-path> = {
    enable = lib.mkEnableOption "description of the module";
  };

  config = lib.mkIf cfg.enable {
    # ...
  };
}
```

- Always define `cfg = config.<option-path>;` as the first `let` binding.
- Extract domain, port, user/group names as `let` bindings — never inline them.

### Option Namespaces & Naming Conventions

- **Files/directories**: lowercase, hyphen-separated (`paperless-ngx.nix`, `home-manager/`)
- **Machine configs**: always `configuration.nix`; disk layouts always `disko.nix`
- **`let` bindings**: camelCase (`serviceUser`, `shareUmask`, `mainUser`, `networkIP`)
- **Options**: camelCase with dot-separated path (`modules.homelab.mediaShare.enable`)

### Imports

- Relative path imports (`./disko.nix`, `../default.nix`, `./services`)
- Never use `with lib;` at file scope — access via `lib.mkIf`, `lib.mkOption`, etc.
- `with pkgs;` is only permitted inside list contexts (e.g. `environment.systemPackages`)
- Selectively import lib functions via `inherit (lib) mkDefault;` when used repeatedly

### Key Lib Functions

- `lib.mkIf` — exclusive conditional mechanism for module config (no `if/then/else`)
- `lib.mkEnableOption` — all enable flags
- `lib.mkOption` — non-boolean options, always with `type`, `default`, `description`
- `lib.mkForce` — sparingly, only for UMask overrides
- `lib.mkMerge` — combining multiple conditional attribute sets
- `lib.mkAfter` — list ordering (e.g. appending to `extraGroups`)
- `lib.mkDefault` — in shared base config for values hosts may override
- `lib.genAttrs` — applying same config to multiple services/users

### String & Comment Patterns

- Port interpolation: `"127.0.0.1:${toString port}"`
- Group references: `"@${shareGroup}"`, home paths: `"/home/${mainUser}"`
- Section headers: short, capitalized (`# Boot configuration`, `# Services`)
- Inline comments: brief, lowercase, for non-obvious choices
- Warnings: emphatic uppercase (`# DO NOT TOUCH THIS`); TODOs: `# TODO: description`

### Secrets Management (sops-nix)

- **age** encryption; keys in `.sops.yaml`; encrypted secrets in `secrets/<host>.yaml`
- Each service declares `sops.secrets.<name>` with `owner`, `group`, `mode = "0400"`
- Consumed via `config.sops.secrets.<name>.path` (usually as `environmentFile`)
- Never commit unencrypted secrets

### Service Wrapper Pattern

Homelab services follow this pattern:
1. Declare `services.<name>-wrapped.enable` with `lib.mkEnableOption`
2. Enable the upstream NixOS service in `config = lib.mkIf cfg.enable { ... }`
3. Register with Caddy via `services.caddy-wrapper.virtualHosts."<name>"`
4. Declare SOPS secrets if needed
5. Set directory permissions via `systemd.tmpfiles.rules`; add group memberships

Services without native NixOS modules (fileflows, streamystats) use OCI containers:
`virtualisation.oci-containers.containers.*` backed by Podman.

### Flake Input Conventions

- All inputs that accept nixpkgs use `inputs.nixpkgs.follows = "nixpkgs"` to pin
- Inputs are grouped with section comments: Core, Deployment, Configuration management
- `specialArgs` passes `inputs` to all modules

## Commit Style

Conventional commits, lowercase: `feat: add jellyfin service`, `fix: caddy domain grouping`,
`chore: update flake inputs`. No scope, no body, short descriptions.
