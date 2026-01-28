# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NixOS Flake-based configuration for a homelab and development environments. Two hosts:
- **adam**: Homelab server (AMD Ryzen, ZFS storage, Intel GPU for transcoding)
- **tabris**: WSL development environment

## Common Commands

```bash
# Rebuild and switch to new configuration
sudo nixos-rebuild switch --flake .#adam    # or #tabris

# Build without switching (test evaluation)
nix build .#nixosConfigurations.adam.config.system.build.toplevel

# Format all Nix files (uses Alejandra)
nix fmt

# Update flake inputs
nix flake update

# Edit encrypted secrets
sops secrets/adam.yaml
```

## Architecture

### Directory Structure
- `flake.nix` - Entry point defining inputs, hosts, and outputs
- `machines/nixos/default.nix` - Shared base configuration for all hosts
- `machines/nixos/{adam,tabris}/` - Host-specific configurations
- `modules/homelab/services/` - Individual service modules with Caddy integration
- `modules/home-manager/` - User environment (shell, git, tools)
- `modules/users/` - System user definitions
- `modules/virtualization/` - Podman container runtime
- `overlays/` - Package customizations (jellyfin-ffmpeg)
- `secrets/` - SOPS-encrypted secrets (age encryption)

### Service Module Pattern

All homelab services follow a wrapper pattern with automatic Caddy reverse proxy integration:

```nix
services.<name>-wrapped.enable = true;  # Enables service + Caddy vhost
```

Services run as `share:share` user/group with umask `0002` for collaborative access.

### Key Integrations
- **Caddy**: Reverse proxy with Cloudflare DNS plugin for all services
- **SOPS**: Secrets management using age encryption (`.sops.yaml` defines key mappings)
- **Home Manager**: User-level config integrated via NixOS module
- **Disko**: Declarative disk partitioning for installations

### Hosts Configuration

Host definitions in `flake.nix` specify system architecture and modules:
- Shared modules applied to all: `machines/nixos` + home-manager
- Host-specific modules added per host (disko, sops, homelab services, WSL)
