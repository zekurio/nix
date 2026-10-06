# nix

Nix configurations for my homelab server, gaming desktop, and MacBook Air,
plus the Home Manager profile they share.

Built with [flake-parts](https://flake.parts) in a dendritic layout — every file
under `modules/` is a flake-parts module discovered by
[import-tree](https://github.com/vic/import-tree), so `flake.nix` only wires
inputs, systems, and the formatter.

### Hosts

| Host | Type | Channel | Description |
|------|------|---------|-------------|
| `adam` | NixOS | unstable | Homelab server: media, photos, documents, behind Caddy; public services on 443, management UIs LAN/tailnet-only |
| `lilith` | NixOS | unstable | Ryzen/Radeon gaming desktop with KDE Plasma on Wayland |
| `sachiel` | nix-darwin | unstable | MacBook Air |

### Layout

```
modules/hosts/<host>/   host entrypoint (system.nix) and host-specific modules
modules/nixos/          shared NixOS modules; default.nix holds the base
modules/darwin/         shared nix-darwin modules
modules/nix/            Nix daemon settings shared by both platforms
modules/homelab/        reusable homelab services (services/<service>/)
modules/home/zekurio/   Home Manager profile, split by concern
modules/nixpkgs/        nixpkgs config and overlays/
secrets/                sops-encrypted, one file per host
```

### Rebuilding

`adam` auto-upgrades from GitHub's `main` branch on a weekly timer, so changes
must be pushed there before an automatic upgrade can use them.
To rebuild explicitly from GitHub:

```bash
ssh adam 'nixos-rebuild switch --flake "github:zekurio/nix/main#adam" --sudo'
```

For routine upgrades, use the upgrade service:

```bash
ssh adam 'sudo systemctl start nixos-upgrade.service'
```

Once the build-safety configuration is deployed, use this same service for
manual and scheduled upgrades. Concurrent starts share one running upgrade;
evaluation and daemon builds share a 3 GiB soft RAM limit, 4 GiB hard RAM
limit, 4 GiB swap limit, and two CPUs. Builds run one derivation at a time
with two workers, using disk for temporary files. The existing 16 GiB ext4
swapfile stays intact. Oversized builds can fail and should be built elsewhere
and cached, rather than raising these limits on production.

Follow progress with `journalctl -fu nixos-upgrade.service`. Automatic reboots
are disabled; schedule kernel reboots separately. Direct `nixos-rebuild`
commands bypass the upgrade serialization and evaluation limits, and root
builds using the local store also bypass the daemon limits.

`lilith` and `sachiel` build from their local checkouts. `path:` keeps the root
activation step from treating the Git working tree as root-owned:

```bash
sudo nixos-rebuild switch --flake path:/home/zekurio/Git/nix#lilith
sudo darwin-rebuild switch --flake path:/Users/zekurio/Git/nix#sachiel
```

Before pushing, run `nix fmt`, `git add` any new files (flakes only see tracked
files), then `nix flake check`.

The weekly lock-file workflow lives in `.github/workflows/` and runs on a
GitHub-hosted runner. Allow GitHub Actions to create pull requests in the
repository settings. Review and merge the PR before Adam can use the updates.

### Bootstrap: macOS

Install upstream multi-user Nix — **not** the Determinate installer — then let
nix-darwin take over. `darwin-rebuild` is not on `PATH` yet and flakes are off
on a fresh install, so the first generation goes through `nix run`:

```bash
sh <(curl -L https://nixos.org/nix/install)
# Start a new shell, then clone the repository.
git clone git@github.com:zekurio/nix.git ~/Git/nix
sudo nix --extra-experimental-features "nix-command flakes" \
    run nix-darwin/master#darwin-rebuild -- switch --flake path:/Users/zekurio/Git/nix#sachiel
```

### Bootstrap: NixOS

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

Install and reboot:

```bash
nixos-install --root /mnt --no-root-passwd --flake "github:zekurio/nix/main#${HOST}"
umount -Rl /mnt
reboot
```

#### Lilith: dual boot and Secure Boot

Lilith uses KDE Plasma on Wayland with SDDM and the default Breeze theme.
PipeWire handles audio with its standard WirePlumber configuration.
The gaming stack includes Steam, Heroic, GameMode, MangoHud, Proton GE, and
Proton CachyOS, with a cached CachyOS kernel from Chaotic.

Lilith's disko layout owns the Samsung NVMe at
`nvme-Samsung_SSD_980_PRO_1TB_S5GXNX0T205473J_1`. Windows stays on the Crucial
drive, which is absent from the layout. The root filesystem is btrfs with
`@`, `@home`, `@nix`, and `@swap` subvolumes and a 16 GiB swapfile.
An existing ext4 installation needs a separate migration or reinstall.
Preserve the EFI partition and its `EFI/Microsoft` directory when migrating.

Limine boots Windows through the firmware's existing `Windows Boot Manager`
entry to preserve its BitLocker measurements. Signing keys are generated,
but firmware enrollment is manual. Test both systems with Secure Boot
disabled first, back up the BitLocker recovery key, and enter firmware
Setup/Custom Mode before enrolling keys:

```bash
sudo sbctl status
sudo sbctl create-keys
sudo sbctl verify
sudo sbctl enroll-keys --microsoft --firmware-builtin
sudo sbctl list-enrolled-keys
sudo sbctl status
```

`create-keys` keeps existing keys. Enrollment includes Microsoft's 2011 and
2023 certificates and the firmware's default db and KEK certificates, alongside
the local signing keys. Do not enroll local keys alone on this board.

`verify` should report the Limine EFI executable as signed. Unsigned kernels
are expected: Limine verifies kernel and initrd hashes against its configuration,
whose hash is embedded in the signed executable.

Enable Secure Boot in firmware and reboot, then confirm `sudo sbctl status`
reports Secure Boot enabled and Setup Mode disabled, and test both
NixOS and Windows. Back up `/var/lib/sbctl` securely; it contains private keys
needed to sign future bootloader updates. Do not commit those keys.

### T3 Code nightly

[t3code-nightly-flake](https://github.com/vsgoulart/t3code-nightly-flake)
packages the upstream nightly release binaries for Lilith and Adam. Both
have the CLI (`t3`); Lilith also has the desktop app (`t3code-desktop`).
Update their pinned nightly with `nix flake update t3code-nightly`, then
rebuild both hosts. Lilith's desktop self-updates are disabled because the
application lives in the Nix store.

Sachiel installs the desktop app through Homebrew's `t3-code@nightly` cask
into `/Applications`. Its version follows Homebrew independently of the
Linux flake pin. Update it with `brew upgrade --cask --greedy t3-code@nightly`.

Adam runs `t3code.service` as `zekurio`, using that user's repositories, Git
configuration, provider credentials, and T3 Code state under `~/.t3`.
The server binds to `127.0.0.1:3773`; Caddy exposes
`https://t3code.zekurio.me` to the LAN and tailnet. The hostname must resolve
to Adam, as the other private service names do.

After rebuilding Adam and Sachiel, generate a pairing link:

```bash
ssh adam 't3 pair'
```

In the printed pairing URL, replace `http://127.0.0.1:3773` with
`https://t3code.zekurio.me`, keeping `/pair#token=...` intact. On Sachiel,
open T3 Code (Nightly), go to **Settings → Connections → Add environment**,
and paste the modified URL. Pairing links expire after five minutes;
generate a fresh link for each device. Provider CLIs must be authenticated
on Adam before starting their threads.

The server starts at boot and survives SSH disconnects. Manage it through
NixOS, rather than `t3 service install`, so rebuilds update the executable:

```bash
ssh adam 'sudo systemctl restart t3code.service'
ssh adam 'journalctl -u t3code.service -f'
```

### Secrets

Host secrets are [sops](https://github.com/getsops/sops)-encrypted under
`secrets/<host>.yaml`, each keyed to that host's age recipient in `.sops.yaml`.
Edit them only with `sops secrets/<host>.yaml`.

`adam` decrypts with an age key at `/var/lib/sops-nix/key.txt` that
is deliberately **not** generated on the host (`generateKey = false`), so a
fresh install has one manual step — without it every secret-dependent service
fails to activate:

```bash
sudo install -Dm600 -o root -g root key.txt /var/lib/sops-nix/key.txt
```
