# nix

Nix configurations for my NixOS hosts and my Mac: a homelab server, a public
edge VPS, and a laptop, plus the Home Manager profile they share.

Built with [flake-parts](https://flake.parts) in a dendritic layout — every file
under `modules/` is a flake-parts module discovered by
[import-tree](https://github.com/vic/import-tree), so `flake.nix` only wires
inputs, systems, and the formatter.

### Hosts

| Host | Type | Channel | Description |
|------|------|---------|-------------|
| `adam` | NixOS | unstable | Homelab server: media, photos, documents, passwords, behind Caddy and a Newt tunnel |
| `ramiel` | NixOS | 26.05 | Hetzner Cloud edge: Pangolin, Gerbil, Traefik, CrowdSec |
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
modules/checks/         flake checks run by `nix flake check`
secrets/                sops-encrypted, one file per host
```

### Rebuilding

`adam` and `ramiel` hold no checkout and build straight from GitHub, so changes
must be pushed to `main` first. They also auto-upgrade from `main` on a timer
(adam weekly, ramiel monthly).

```bash
ssh adam 'nixos-rebuild switch --flake github:zekurio/nix#adam --sudo'
```

`sachiel` builds from the local checkout. `path:` keeps the root activation step
from treating the Git working tree as root-owned:

```bash
sudo darwin-rebuild switch --flake path:/Users/zekurio/Git/nix#sachiel
```

Before pushing, run `nix fmt`, `git add` any new files (flakes only see tracked
files), then `nix flake check`.

### Bootstrap: macOS

Install upstream multi-user Nix — **not** the Determinate installer — then let
nix-darwin take over. `darwin-rebuild` is not on `PATH` yet and flakes are off
on a fresh install, so the first generation goes through `nix run`:

```bash
sh <(curl -L https://nixos.org/nix/install)
# new shell, then clone this repo to ~/Git/nix
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
nixos-install --root /mnt --no-root-passwd --flake "github:zekurio/nix#${HOST}"
umount -Rl /mnt
reboot
```

### Secrets

Host secrets are [sops](https://github.com/getsops/sops)-encrypted under
`secrets/<host>.yaml`, each keyed to that host's age recipient in `.sops.yaml`.
Edit them only with `sops secrets/<host>.yaml`.

`adam` and `ramiel` decrypt with an age key at `/var/lib/sops-nix/key.txt` that
is deliberately **not** generated on the host (`generateKey = false`), so a
fresh install has one manual step — without it every secret-dependent service
fails to activate:

```bash
sudo install -Dm600 -o root -g root key.txt /var/lib/sops-nix/key.txt
```
