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

On `lilith` or `sachiel`, rebuild from the local checkout:

```bash
# lilith
sudo nixos-rebuild switch --flake path:/home/zekurio/Git/nix#lilith

# sachiel
sudo darwin-rebuild switch --flake path:/Users/zekurio/Git/nix#sachiel
```

Keep `path:` so root activation can read the user-owned checkout. Merge the
weekly `flake.lock` PR to deploy input updates through these same commands.

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
