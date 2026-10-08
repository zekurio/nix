# nix

Nix configurations for my homelab server, gaming desktop, and MacBook Air,
plus the Home Manager profile they share.

| Host | Type | Role |
|------|------|------|
| `adam` | NixOS | Homelab server |
| `lilith` | NixOS | Gaming desktop, dual-booting Windows |
| `sachiel` | nix-darwin | MacBook Air |

This is a [flake-parts](https://flake.parts) flake in a dendritic layout.
`AGENTS.md` covers the structure and conventions, and each module explains
itself in comments. This file only lists the steps you run by hand.

## Rebuilding

`adam` upgrades itself from GitHub's `main` every Sunday around 03:00, so a
change reaches it only after a push. To upgrade now, start the unit the timer
uses and follow its log:

```bash
ssh adam 'sudo systemctl start nixos-upgrade.service'
ssh adam 'journalctl -fu nixos-upgrade.service'
```

That unit runs inside the memory and CPU limits from
`modules/hosts/adam/build-safety.nix`. A build that hits them fails. Build it
on another machine and push it to the cache instead of raising the limits.
Upgrades never reboot the host, so reboot by hand for a new kernel.

A direct rebuild bypasses those limits. Keep it for emergencies:

```bash
ssh adam 'nixos-rebuild switch --flake "github:zekurio/nix/main#adam" --sudo'
```

`lilith` and `sachiel` build from their local checkouts. `path:` keeps the root
activation step from treating the Git working tree as root-owned:

```bash
sudo nixos-rebuild switch --flake path:/home/zekurio/Git/nix#lilith
sudo darwin-rebuild switch --flake path:/Users/zekurio/Git/nix#sachiel
```

A GitHub workflow opens a `flake.lock` update PR every Saturday night. It needs
"Allow GitHub Actions to create and approve pull requests" enabled in the
repository settings. `adam` picks the update up after you merge the PR.

## Bootstrap

### macOS

Install upstream multi-user Nix, not the Determinate installer, then let
nix-darwin take over. `darwin-rebuild` is not on `PATH` yet and flakes are off
on a fresh install, so the first generation goes through `nix run`:

```bash
sh <(curl -L https://nixos.org/nix/install)
# Start a new shell, then clone the repository.
git clone git@github.com:zekurio/nix.git ~/Git/nix
sudo nix --extra-experimental-features "nix-command flakes" \
    run nix-darwin/master#darwin-rebuild -- switch --flake path:/Users/zekurio/Git/nix#sachiel
```

### NixOS

Boot the installer, enable flakes, then partition and mount with
[disko](https://github.com/nix-community/disko) using the host's own layout:

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

HOST=adam
DISK='/dev/disk/by-id/<your-disk-id>'

curl -o /tmp/disko.nix \
    "https://raw.githubusercontent.com/zekurio/nix/main/modules/hosts/${HOST}/disko.nix"
sed -i "s|device = \"/dev/disk/by-id/[^\"]*\"|device = \"${DISK}\"|" /tmp/disko.nix
nix --experimental-features "nix-command flakes" run github:nix-community/disko \
    -- -m destroy,format,mount /tmp/disko.nix
```

Destroy mode wipes the disk you name. On `lilith` that must be the Samsung
NVMe, because Windows lives on the Crucial drive.

Install and reboot:

```bash
nixos-install --root /mnt --no-root-passwd --flake "github:zekurio/nix/main#${HOST}"
umount -Rl /mnt
reboot
```

### Adam's age key

`adam` decrypts its secrets with an age key that the host never generates.
Until you place it, every service that needs a secret fails to activate:

```bash
sudo install -Dm600 -o root -g root key.txt /var/lib/sops-nix/key.txt
```

### Lilith's Secure Boot keys

Limine generates its signing keys, but you enroll them in the firmware by
hand. First test NixOS and Windows with Secure Boot disabled, back up the
BitLocker recovery key, and put the firmware in Setup/Custom Mode. Then:

```bash
sudo sbctl status
sudo sbctl create-keys
sudo sbctl verify
sudo sbctl enroll-keys --microsoft --firmware-builtin
sudo sbctl list-enrolled-keys
sudo sbctl status
```

`create-keys` keeps existing keys. The enrollment adds Microsoft's 2011 and
2023 certificates and the firmware's default db and KEK certificates next to
the local keys. Do not enroll the local keys alone on this board.

`verify` should report the Limine EFI executable as signed. Unsigned kernels
are expected. Limine checks the kernel and initrd hashes against its
configuration, and the signed executable embeds that configuration's hash.

Enable Secure Boot in the firmware and reboot. `sudo sbctl status` should then
report Secure Boot enabled and Setup Mode disabled. Test both systems again.
Back up `/var/lib/sbctl` somewhere safe and never commit it. It holds the
private keys that sign every future bootloader update.

## Operations

### T3 Code

Bump the Linux packages with `nix flake update t3code-nightly`, then rebuild
`lilith` and `adam`. `sachiel` follows Homebrew instead:
`brew upgrade --cask --greedy t3-code@nightly`.

To connect a device to the server on `adam`, generate a pairing link:

```bash
ssh adam 't3 pair'
```

In the printed URL, replace `http://127.0.0.1:3773` with
`https://t3code.zekurio.me` and keep `/pair#token=...` intact. In T3 Code, open
Settings → Connections → Add environment and paste it. A link expires after
five minutes, so generate one per device. Authenticate the provider CLIs on
`adam` before you start their threads.

Do not run `t3 service install` on `adam`. NixOS owns the unit, so a rebuild
updates the executable:

```bash
ssh adam 'sudo systemctl restart t3code.service'
ssh adam 'journalctl -u t3code.service -f'
```

### Fluxer

After an update, check login, messages, attachment uploads, and a voice call.
Read the upstream configuration changes before you bump any image tag.

A full reset needs these steps in order:

1. Stop `fluxer.target`.
2. Take a database dump and a copy or snapshot of the state, and keep them
   outside `tank/fluxer`.
3. Reset only the `fluxer` database. Leave the shared PostgreSQL data
   directory alone.
4. Reset the NATS, Valkey, Meilisearch, and SeaweedFS state folders together.
5. Recreate the SSD directories with
   `systemd-tmpfiles --create --prefix=/var/lib/fluxer`, then start the target.

### Leftovers from the beets migration

The 2026-09-21 migration from Lidarr to beets left these on `adam`. Nothing in
the configuration uses or removes them:

- Music snapshot `tank/media@before-beets-migration-20260921`
- Original beets state and the last legacy download in
  `/var/backups/beets-migration-20260921/`
- `/var/lib/beets/migration-lyrics-report.json`
- `/var/lib/beets/migration-flac-repairs.json`
- `/var/lib/beets/migration-final-audit.json`

The reports list lookup failures that still need a review. Once that is done,
destroy the snapshot and the backup, then delete this section.

## Secrets

Host secrets are [sops](https://github.com/getsops/sops)-encrypted in
`secrets/<host>.yaml` for the age recipients in `.sops.yaml`. Edit them only
with `sops secrets/<host>.yaml`.
