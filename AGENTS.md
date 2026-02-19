# AGENTS.md

NixOS flake configuration repository managing four hosts. The entire codebase is Nix --
there are no shell scripts, no test suites, and no CI/CD pipelines.

| Host | Role | Key traits |
|------|------|------------|
| `adam` | Homelab server | ZFS, Intel QSV, 18+ wrapped services, Caddy, Samba/NFS, SOPS secrets |
| `tabris` | WSL dev box | NixOS-WSL, minimal config |
| `lilith` | Desktop workstation | AMD GPU, Limine boot, Niri compositor, gaming |
| `shamshel` | VPS | QEMU guest, FRP server, SOPS secrets, auto-upgrade |

## Build / Format / Evaluate Commands

```bash
# Format all Nix files (alejandra) -- run before every commit
nix fmt

# Build a specific host (does NOT activate)
nix build .#nixosConfigurations.<host>.config.system.build.toplevel

# Evaluate a single host to check for errors (fast, no derivation build)
nix eval .#nixosConfigurations.<host>.config.system.build.toplevel --raw 2>&1 | head -1
# or dry-run:
nixos-rebuild dry-build --flake .#<host>

# Evaluate a single option (useful to validate a single module change)
nix eval .#nixosConfigurations.adam.config.services.jellyfin.enable

# Apply configuration on the running host
sudo nixos-rebuild switch --flake .#<host>

# Validate the entire flake
nix flake check

# Update all / single flake input
nix flake update
nix flake update <input-name>
```

There are no unit tests. Validation is done by evaluating or building host configurations.

## Repository Structure

```
flake.nix                      # Root flake (flake-parts): inputs, host map, outputs
machines/nixos/
  default.nix                  # Shared base config imported by ALL hosts
  adam/configuration.nix       # Homelab server
  adam/disko.nix               # Disk layout (GPT, EFI + ext4)
  tabris/configuration.nix     # WSL dev box
  lilith/configuration.nix     # Desktop workstation
  lilith/disko.nix
  shamshel/configuration.nix   # VPS
  shamshel/disko.nix
modules/
  home-manager/                # User-level config (shell.nix always-on, desktop/ opt-in)
  homelab/services/            # Homelab service modules (one file per service)
  users/                       # User definitions + home-manager bootstrap
  virtualization/              # Rootless Podman setup
  workstation/                 # NixOS-level workstation modules (desktop, gaming, etc.)
overlays/                      # Package overlays (e.g. jellyfin-ffmpeg)
secrets/                       # SOPS-encrypted secrets (age keys, per-host YAML)
```

### Aggregator pattern

Every directory has a `default.nix` that **only** imports child modules and contains no
logic. Aggregator files use either `{...}:` or bare `{ imports = [...]; }` as their form.

## Code Style

### Formatter

All code must pass **alejandra** (`nix fmt`). Run it before committing.

### Module structure

Every module follows this exact template:

```nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.<option-path>;
  domain = "example.com";
  port = 8080;
in {
  options.<option-path> = {
    enable = lib.mkEnableOption "description";
  };

  config = lib.mkIf cfg.enable {
    # ...
  };
}
```

- `cfg = config.<option-path>;` is always the first `let` binding.
- Extract domain, port, user/group names as `let` bindings -- never inline them.

### Naming conventions

| What | Style | Examples |
|------|-------|---------|
| Files / directories | lowercase hyphen-separated | `paperless-ngx.nix`, `home-manager/` |
| Machine configs | always `configuration.nix` | `adam/configuration.nix` |
| Disk layouts | always `disko.nix` | `adam/disko.nix` |
| `let` bindings | camelCase | `serviceUser`, `shareUmask`, `mainUser` |
| Option paths | camelCase dot-separated | `modules.homelab.mediaShare.enable` |
| Homelab service options | `services.<name>-wrapped.enable` | `services.jellyfin-wrapped.enable` |
| Workstation options | `modules.workstation.<name>.enable` | `modules.workstation.desktop.enable` |
| Home-manager options | `modules.hm.<name>.enable` | `modules.hm.shell.enable` |

### Imports

- Always use relative paths (`./disko.nix`, `../default.nix`, `./services`).
- **Never** use `with lib;` at file scope -- access via `lib.mkIf`, `lib.mkOption`, etc.
- `with pkgs;` is **only** permitted inside list contexts (e.g. `environment.systemPackages`).
- Use `inherit (lib) mkDefault;` when the same function is called repeatedly.

### Key lib functions

- `lib.mkIf` -- exclusive conditional for module config (**never** use `if/then/else`)
- `lib.mkEnableOption` -- all enable flags
- `lib.mkOption` -- non-boolean options; always set `type`, `default`, `description`
- `lib.mkDefault` -- in shared base config for values hosts may override
- `lib.mkForce` -- sparingly; only for UMask overrides
- `lib.mkMerge` -- combining multiple conditional attribute sets
- `lib.mkAfter` -- list ordering (appending to `extraGroups`)
- `lib.genAttrs` -- applying same config to multiple services/users

### Strings and comments

- Port interpolation: `"127.0.0.1:${toString port}"`
- Group references: `"@${shareGroup}"`, home paths: `"/home/${mainUser}"`
- Section headers: short, capitalized (`# Boot configuration`)
- Inline comments: brief, lowercase, for non-obvious choices only
- Warnings: emphatic uppercase (`# DO NOT TOUCH THIS`)
- TODOs: `# TODO: description`

### Secrets (sops-nix)

- **age** encryption; keys declared in `.sops.yaml`; secrets in `secrets/<host>.yaml`
- Declare: `sops.secrets.<name> = { owner = "..."; group = "..."; mode = "0400"; };`
- Consume: `config.sops.secrets.<name>.path` (usually as `environmentFile`)
- Never commit unencrypted secrets

### Homelab service wrapper pattern

1. Declare `services.<name>-wrapped.enable` with `lib.mkEnableOption`
2. Enable the upstream NixOS service inside `config = lib.mkIf cfg.enable { ... }`
3. Register with Caddy: `services.caddy-wrapper.virtualHosts."<name>" = { domain; reverseProxy; }`
4. Declare SOPS secrets if needed
5. Set directory permissions via `systemd.tmpfiles.rules`; add group memberships

Services without native NixOS modules use OCI containers via
`virtualisation.oci-containers.containers.*` backed by Podman.

Sub-path services (sonarr, radarr, prowlarr) share a domain using URL base paths and
Caddy path matchers in `extraConfig`.

### Flake input conventions

- All inputs that accept nixpkgs use `inputs.nixpkgs.follows = "nixpkgs"`
- Inputs are grouped with section comments (Core, Deployment, Configuration management)
- `specialArgs` passes `inputs` to all modules

## Commit Style

Conventional commits, lowercase, no scope, no body:
`feat: add jellyfin service`, `fix: caddy domain grouping`, `chore: update flake inputs`
