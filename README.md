# nix-config

Declarative NixOS and WSL configurations for homelab and workstation deployments. This repository demonstrates how to manage multiple machines from a single Nix flake using reusable modules, profiles, and secrets management.

## Quick Start

**Want to see how this works?**
- Review `flake.nix` for the overall structure and input dependencies
- Check `machines/nixos/<host>/configuration.nix` to see host-specific settings
- Run `nix flake check` to validate the configuration

**Ready to deploy?**
- For fresh machines: See [Remote Installation](#remote-installation-with-nixos-anywhere)
- For existing machines: Run `nixos-rebuild switch --flake .#<host>`

## Repository Structure

```
machines/nixos/           # Host-specific configurations
├── adam/                 # Homelab server (bare metal)
│   ├── configuration.nix
│   └── disko.nix         # Disk layout
├── tabris/               # Development environment (WSL)
│   └── configuration.nix
└── default.nix

modules/                  # Reusable NixOS and Home Manager modules
├── homelab/              # Self-hosted services (media stack, backups, etc.)
├── profiles/
│   └── dev.nix           # Developer tools and environment
├── system/               # System-level defaults
├── users/                # User configuration
└── graphics/             # Display server setup

overlays/                 # Custom package overlays
secrets/                  # Encrypted SOPS configuration files
flake.nix                 # Flake entry point and dependency management
```

### What's Inside Each Directory

- **`modules/homelab`** — Self-hosted services (Arr stack, Vaultwarden, Navidrome) and Podman wrappers. Only applied to `adam`.
- **`modules/profiles/dev.nix`** — Home Manager driven developer experience: CLI tools, Git config, shell plugins, SSH setup.
- **`modules/system` and `modules/users`** — Cross-host defaults for system settings and user management.
- **`secrets/*.yaml`** — Encrypted with SOPS; decryption keys stored securely on each host.

## Hosts

- **`adam`** — Homelab server running media services, backups, and VPN confinement. Uses bare-metal hardware with disk management via disko.
- **`tabris`** — Pure development environment inside NixOS-WSL. Uses Home Manager profile only (no system services).

## Common Tasks

### Validate Configuration

```bash
nix flake check
```

Runs audits to ensure imports are correct and the flake is valid.

### Build Without Switching

```bash
nixos-rebuild build --flake .#adam
```

Materializes the system closure for inspection. Useful before committing changes.

### Apply Configuration Locally

```bash
nixos-rebuild switch --flake .#<host>
```

### Apply Configuration Remotely

```bash
nixos-rebuild switch --flake .#adam --target-host root@adam.lan --use-remote-sudo
```

## Remote Installation with nixos-anywhere

Deploy a fresh machine over SSH from any Nix-enabled controller.

### 1. Prepare the Target

1. Boot the target host from the latest minimal NixOS ISO.
2. Become `root` and configure networking: `systemctl start sshd`.
3. Set a temporary root password (`passwd`) or provision an SSH key.
4. For bare-metal machines, verify `machines/nixos/<host>/disko.nix` matches the hardware layout.

### 2. Run nixos-anywhere

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#adam \
  --target-host root@adam.lan \
  --build-on-remote \
  --no-reboot
```

- Replace `adam` and the hostname/IP with your target machine.
- `--build-on-remote` compiles on the target to avoid large network transfers.
- `--no-reboot` allows you to upload secrets before the first boot.

### 3. Seed SOPS Keys and Reboot

```bash
ssh root@adam.lan 'install -m 700 -d /var/lib/sops-nix'
scp ~/.config/sops/age/keys.txt root@adam.lan:/var/lib/sops-nix/key.txt
ssh root@adam.lan 'chmod 600 /var/lib/sops-nix/key.txt'
ssh root@adam.lan reboot
```

Confirm activation works after reboot:

```bash
nixos-rebuild switch --flake .#adam --target-host root@adam.lan --use-remote-sudo
```

## WSL Setup (tabris)

`tabris` uses the official NixOS-WSL module for Windows Subsystem for Linux.

### Create or Refresh the Tarball

```bash
nix build .#nixosConfigurations.tabris.config.system.build.tarball
wsl --import tabris "$HOME/WSL/tabris" result/nixos-wsl.tar.gz --version 2
```

### Update Configuration After Import

```bash
sudo nixos-rebuild switch --flake .#tabris
```

Shell aliases like `rebuild-tabris` are pre-defined for convenience.

## Backup and Recovery (adam)

Restic backups are configured by `modules/homelab/services/backups.nix` and target Backblaze B2.

### Restore Files

1. Enter a shell with restic available:
   ```bash
   sudo nix shell nixpkgs#restic -c bash
   ```

2. Load backup credentials:
   ```bash
   set -a
   source /run/secrets/restic_env
   set +a
   export RESTIC_PASSWORD_FILE=/run/secrets/restic_password
   ```

3. List available snapshots:
   ```bash
   restic snapshots --tag adam
   ```

4. Restore to a staging directory:
   ```bash
   mkdir -p /var/restore
   restic restore latest --tag adam --target /var/restore --include /var/lib/sonarr
   ```

5. Move recovered files to their destination and clean up.

### Optional: Inspect Changes

```bash
restic diff <snapshot-id> latest --tag adam --path /var/lib/sonarr
restic mount /mnt/restic  # Browse with FUSE; remember to unmount
```

## Contributing

See [AGENTS.md](AGENTS.md) for coding standards, testing guidelines, and commit practices.