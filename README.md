# Deploying my systems

- `adam`: NixOS homelab server.
- `lilith`: NixOS desktop, dual-booting Windows.
- `sachiel`: MacBook Air with nix-darwin.

## Rebuild

For `adam`, push changes to `main`, then start the upgrade and follow its log:

```bash
ssh adam 'sudo systemctl start nixos-upgrade.service'
ssh adam 'journalctl -fu nixos-upgrade.service'
```

The same unit runs every Sunday between 03:00 and 03:45. It never reboots;
reboot by hand for a new kernel. If a build hits the unit's resource limits,
build elsewhere and push it to the cache.

For emergencies, run a direct rebuild. This bypasses the upgrade unit's limits:

```bash
ssh adam 'nixos-rebuild switch --flake github:zekurio/nix/main#adam --sudo'
```

On `lilith` or `sachiel`, rebuild from the local checkout with `nh`, which
finds `~/Git/nix` on its own and prints a package diff before activating:

```bash
nh os switch      # lilith
nh darwin switch  # sachiel
```

`nh os boot` activates on the next reboot instead. Stage new files first, as
with any git flake.

`lilith` also builds `main` every day and sets it as the boot default without
switching, so merging the weekly `flake.lock` PR is enough to update it on the
next reboot. A reboot also drops any generation switched to from unpushed
local changes. `sachiel` needs `nh darwin switch` after a merge.

If `nh` is unavailable, rebuild directly. Keep `path:` so root can read the
user-owned checkout:

```bash
sudo nixos-rebuild switch --flake path:/home/zekurio/Git/nix#lilith
sudo darwin-rebuild switch --flake path:/Users/zekurio/Git/nix#sachiel
```

## Install NixOS

Boot the NixOS installer in UEFI mode and open a root shell:

```bash
sudo -i
export NIX_CONFIG='experimental-features = nix-command flakes'
nix-shell -p git --run 'git clone https://github.com/zekurio/nix.git /tmp/nix'
cd /tmp/nix
INSTALL_HOST=adam  # or lilith
lsblk -o NAME,SIZE,MODEL,MOUNTPOINTS
ls -l /dev/disk/by-id/
```

Edit `modules/hosts/$INSTALL_HOST/disko.nix`. Set `device` to the full
`/dev/disk/by-id/...` path for the system disk. On `lilith`, use the Samsung
NVMe. Leave the Crucial Windows drive alone.

The next command wipes the configured system disk and mounts it at `/mnt`:

```bash
nix run github:nix-community/disko -- \
    --mode destroy,format,mount --flake ".#${INSTALL_HOST}"
```

For `adam`, restore the saved age key before installing. Use the key matching
the recipient in `.sops.yaml`; the host does not generate one:

```bash
install -Dm600 -o root -g root /path/to/key.txt /mnt/var/lib/sops-nix/key.txt
```

Install from the same checkout so it uses the disk path you just set:

```bash
nixos-install --root /mnt --no-root-passwd --flake ".#${INSTALL_HOST}"
umount -Rl /mnt
reboot
```

Keep Secure Boot disabled on `lilith` until you enroll its keys below.

## Install macOS

Install upstream multi-user Nix, then open a new shell:

```bash
sh <(curl -L https://nixos.org/nix/install)
```

Use the upstream installer rather than Determinate so nix-darwin can manage Nix.
Clone the repository and build the first generation:

```bash
git clone git@github.com:zekurio/nix.git ~/Git/nix
sudo nix --extra-experimental-features 'nix-command flakes' \
    run nix-darwin/master#darwin-rebuild -- switch \
    --flake path:/Users/zekurio/Git/nix#sachiel
```

## Enroll Lilith's Secure Boot keys

Test NixOS and Windows with Secure Boot disabled. Save the BitLocker recovery
key, then put the firmware in Setup/Custom Mode.

```bash
sudo sbctl status
sudo sbctl create-keys
sudo sbctl verify
sudo sbctl enroll-keys --microsoft --firmware-builtin
sudo sbctl list-enrolled-keys
sudo sbctl status
```

`create-keys` keeps existing keys. `verify` should show the Limine EFI executable
as signed; unsigned kernels are expected. Keep the Microsoft and firmware keys
when enrolling so Windows and the board's firmware components still boot.

Enable Secure Boot and reboot. `sudo sbctl status` should report Secure Boot
enabled and Setup Mode disabled. Test both systems again. Back up `/var/lib/sbctl`
securely; it contains private signing keys. Never commit it.

## Edit secrets

Edit encrypted host secrets with sops, then rebuild the host:

```bash
sops secrets/adam.yaml
```

Keep plaintext out of `secrets/`. Age recipients live in `.sops.yaml`.

## Upgrade adam's PostgreSQL

`modules/hosts/adam/postgresql.nix` pins the major version. A bump moves the
cluster to `/var/lib/postgresql/<major>`, and switching without migrating
starts Immich, Fluxer and Alloy on an empty one. On `adam`, from the
checkout with the bump, before switching:

```bash
OLD=$(systemctl cat postgresql | grep -om1 '/nix/store/[^/ ]*-postgresql-and-plugins-[0-9.]*')
NEW=$(nix build --no-link --print-out-paths .#nixosConfigurations.adam.config.services.postgresql.finalPackage)
OLDDATA=/var/lib/postgresql/16 NEWDATA=/var/lib/postgresql/18

sudo systemctl stop immich-server immich-machine-learning alloy-server fluxer.target postgresql
sudo install -d -m 0700 -o postgres -g postgres "$NEWDATA"
# The old cluster has no data checksums; pg_upgrade needs both to match.
sudo -u postgres "$NEW/bin/initdb" -U postgres --no-data-checksums -D "$NEWDATA"
sudo -u postgres env -C "$NEWDATA" "$NEW/bin/pg_upgrade" -U postgres \
  --old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
  --old-bindir "$OLD/bin" --new-bindir "$NEW/bin" \
  --old-options "-c config_file=$OLDDATA/postgresql.conf" \
  --new-options "-c shared_preload_libraries=vchord"
```

Then switch to the new configuration, run
`sudo -u postgres vacuumdb --all --analyze-in-stages`, and delete `$OLDDATA`
once the services work.

## Back up adam

Run the nightly backup by hand and follow it. The offsite upload starts after
the copy to tank when it is enabled:

```bash
ssh adam 'sudo systemctl start backup-state.service'
ssh adam 'journalctl -fu backup-state.service -u restic-backups-offsite.service'
```

Failures of either unit arrive through ntfy.

## Restore adam's SSD from tank

Follow [Install NixOS](#install-nixos) through the disko step, with the new
SSD's path in `disko.nix`. The copy carries the age key, so skip restoring it.
`@backup` is the newest complete copy; `zfs list -t snapshot tank/backups/adam`
lists the dailies, which mount the same way:

```bash
zpool import -f -N -o readonly=on tank
mkdir /backup
mount -t zfs tank/backups/adam@backup /backup
rsync -aHAX --numeric-ids --exclude /boot/ --exclude /etc/ /backup/ /mnt/
install -d /mnt/etc/ssh
cp -a /backup/etc/machine-id /mnt/etc/
cp -a /backup/etc/ssh/ssh_host_* /mnt/etc/ssh/
umount /backup
zpool export tank
nixos-install --root /mnt --no-root-passwd --flake ".#adam"
```

Reboot. `/var/lib/nixos` came back before the install, so every service keeps
its UID, and Postgres starts from the data directory copied while it was
stopped. Podman pulls its images again on first start.

## Set up the offsite backup

Order a Hetzner Storage Box and enable SSH support. Create a sub-account for
adam with SSH support, and turn on the box's automatic snapshots: restic can
delete whatever it wrote, but only the Hetzner Console can delete those. Keep
the sub-account writable, or restic cannot prune.

```bash
BOX=uXXXXXX-subN.your-storagebox.de
ssh-keygen -t ed25519 -N '' -C restic@adam -f restic_ssh_key
ssh-copy-id -p 23 -s -i restic_ssh_key.pub "${BOX%%.*}@$BOX"
ssh-keyscan -p 23 "$BOX"
openssl rand -base64 48
```

Add the random string as `restic_password` and the private key as a YAML block
under `restic_ssh_key` with `sops secrets/adam.yaml`, then delete
`restic_ssh_key`. In `modules/hosts/adam/backup.nix`, set `offsite.host` to
`$BOX`, `offsite.hostKey` to the `ssh-ed25519` key `ssh-keyscan` printed, and
`offsite.enable = true`. Deploy and run a backup by hand. The first upload
takes a while.

Save the password in your password manager as well. Without it nobody can
read the repository, and otherwise the saved age key would be the only way to
reach it. A lost SSH key can be replaced through the Hetzner Console.

## Restore from the offsite backup

When tank is gone too, reinstall per [Install NixOS](#install-nixos), restoring
the age key. Before `nixos-install`, restore the UID map so restored files keep
their owners, and create the new pool:

```bash
BOX=uXXXXXX-subN.your-storagebox.de
nix-shell -p restic sops
export SOPS_AGE_KEY_FILE=/mnt/var/lib/sops-nix/key.txt
sops -d --extract '["restic_password"]' secrets/adam.yaml > /tmp/restic-password
(umask 077; sops -d --extract '["restic_ssh_key"]' secrets/adam.yaml > /tmp/restic-key)
restic -r "sftp:${BOX%%.*}@$BOX:restic" \
  -o sftp.command="ssh -p 23 -i /tmp/restic-key ${BOX%%.*}@$BOX -s sftp" \
  --password-file /tmp/restic-password \
  restore latest --include /var/lib/nixos --target /mnt
zpool create -o ashift=12 -O compression=zstd -O atime=off -O acltype=posix \
  -O xattr=sa -O mountpoint=/tank tank mirror /dev/disk/by-id/DISK1 /dev/disk/by-id/DISK2
zpool export tank
```

After the install and a reboot, restore the data and databases over the fresh
services:

```bash
sudo systemctl stop immich-server immich-machine-learning alloy-server pocket-id fluxer.target
sudo restic-offsite restore latest --target /
for db in immich alloy fluxer; do
  sudo -u postgres dropdb --if-exists "$db"
  sudo -u postgres pg_restore --create --dbname postgres "/var/backup/postgresql/$db.dump"
done
sudo systemctl restart mediaShare-user-library-acl
sudo systemctl start immich-server immich-machine-learning alloy-server pocket-id fluxer.target
```

Then run Immich's thumbnail and video transcoding jobs for missing assets, since
the repository leaves both out.
