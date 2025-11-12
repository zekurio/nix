# nix-config

Declarative NixOS and WSL configurations for the homelab, workstations, and developer environments that live on my machines. All hosts are built from a single flake with reusable modules and service wrappers.

## Layout

```text
machines/nixos
├── adam/
│   ├── configuration.nix
│   └── disko.nix
├── lilith/
│   ├── configuration.nix
│   └── disko.nix
├── tabris/
│   └── configuration.nix
└── default.nix
modules
├── homelab/
│   ├── default.nix
│   ├── podman.nix
│   └── services/
├── home-manager/
├── desktop/
├── development/
├── gaming/
├── graphics/
├── system/
├── users/
└── virtualization/
overlays/
secrets/
```

`modules/homelab` collects self-hosted services (Arr stack, Vaultwarden, Navidrome, etc.) and the Podman wrapper used on `adam`. `modules/home-manager` defines the user environment layers, while `modules/system` and friends provide cross-host defaults. Secrets are encrypted with SOPS and stored under `secrets/*.yaml`.

## Hosts

- `adam` – homelab server with the typical media services, SOPS managed secrets, and restic backups.
- `lilith` – AMD desktop with Hyprland, gaming modules, and Secure Boot via Lanzaboote.
- `tabris` – NixOS-WSL environment; this is the only Windows-hosted configuration.

## Remote installation with nixos-anywhere

The easiest way to deploy a fresh machine is to install over SSH from a controller that has Nix available.

### 1. Prepare the target

1. Boot the target host from the latest minimal NixOS ISO.
2. Become `root`, configure networking (Wi-Fi or Ethernet), and start SSH: `systemctl start sshd`.
3. Set a temporary root password (`passwd`) or provision an SSH key so the controller can connect.
4. If the host uses `disko` (all bare-metal machines here do), verify the definitions in `machines/nixos/<host>/disko.nix` match the hardware before continuing.

### 2. Run nixos-anywhere from the controller

From the repository root on your workstation:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#adam \
  --target-host root@adam.lan \
  --build-on-remote \
  --no-reboot
```

- Swap `adam` and the hostname/IP for the machine you are provisioning.
- `--build-on-remote` avoids copying large closures over the network by compiling on the target.
- Keep `--no-reboot` so you can upload secrets before the first boot.

nixos-anywhere will apply the `disko` layout, generate hardware configuration, and install the system defined by the selected flake output.

### 3. Seed SOPS keys and reboot

```bash
ssh root@adam.lan 'install -m 700 -d /var/lib/sops-nix'
scp ~/.config/sops/age/keys.txt root@adam.lan:/var/lib/sops-nix/key.txt
ssh root@adam.lan 'chmod 600 /var/lib/sops-nix/key.txt'
ssh root@adam.lan reboot
```

Adjust the key path if your age key lives elsewhere. Once the machine boots, confirm the activation works with `nixos-rebuild switch --flake .#adam --target-host root@adam.lan --use-remote-sudo`.

### Lanzaboote first-boot note

Lanzaboote and systemd-boot do not cooperate during the initial install. For hosts that enable Lanzaboote (currently `lilith`), provision the first image with `boot.loader.systemd-boot.enable = true` and `boot.lanzaboote.enable = false`. After the machine boots successfully, re-enable Lanzaboote in the configuration, rebuild, and enroll the Secure Boot keys (`sbctl sign-all && nixos-rebuild switch --flake .#lilith`).

## Working with the WSL config (tabris)

`tabris` uses the official NixOS-WSL module. To create or refresh the tarball:

```bash
nix build .#nixosConfigurations.tabris.config.system.build.tarball
wsl --import tabris "$HOME/WSL/tabris" result/nixos-wsl.tar.gz --version 2
```

After importing, start the distribution and run `sudo nixos-rebuild switch --flake .#tabris` to pick up any local changes. Convenience aliases such as `rebuild-tabris` are defined inside the environment.

## Day-to-day operations

- `nix flake check` – run repository checks before pushing changes.
- `nixos-rebuild switch --flake .#<host>` – activate configuration locally or with `--target-host` for remote updates.
- `nixos-rebuild build --flake .#adam` – build the closure without switching (useful for inspection).
- `nix develop` or `nix shell` can provide the deployment toolchain when working from a rescue ISO.

## Backup recovery (adam)

Restic backups are configured by `modules/homelab/services/backups.nix` and target Backblaze B2.

1. Become the backup user (`root` by default) and enter a shell with restic available:
   ```bash
   sudo nix shell nixpkgs#restic -c bash
   ```
2. Load the secrets exposed by the module:
   ```bash
   set -a
   source /run/secrets/restic_env
   set +a
   export RESTIC_PASSWORD_FILE=/run/secrets/restic_password
   ```
3. Inspect snapshots tagged for `adam`:
   ```bash
   restic snapshots --tag adam
   ```
4. Restore into a staging directory and pull what you need:
   ```bash
   mkdir -p /var/restore
   restic restore latest --tag adam --target /var/restore --include /var/lib/sonarr
   ```
5. Move recovered files into place (stop services first if you overwrite live data) and clean up `/var/restore` when finished.

Optional checks:
- `restic diff <snapshot-id> latest --tag adam --path /var/lib/sonarr` to review changes.
- `restic mount /mnt/restic` for FUSE-based browsing (remember to unmount after use).
