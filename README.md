# nix-config

NixOS configurations for my homelab, servers, and workstation

## Hosts

| Host | Description |
|------|-------------|
| `adam` | Homelab server (ZFS, Intel QSV, Caddy, Samba/NFS) |
| `sachiel` | Workstation desktop (`niri` + `dankmaterialshell`) |
| `tabris` | WSL dev box |
| `lilith` | VPS (FRP server, auto-upgrade) |

## Installation runbook (NixOS)

Boot into the NixOS installer and enable flakes

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Partition and mount the drives using [disko](https://github.com/nix-community/disko)

```bash
HOST=adam  # adam, lilith
DISK='/dev/disk/by-id/<your-disk-id>'

curl -o /tmp/disko.nix \
    "https://raw.githubusercontent.com/zekurio/nix/main/modules/hosts/${HOST}/disko.nix"
sed -i "s|device = \"/dev/disk/by-id/[^\"]*\"|device = \"${DISK}\"|" /tmp/disko.nix
nix --experimental-features "nix-command flakes" run github:nix-community/disko \
    -- -m destroy,format,mount /tmp/disko.nix
```

Install git and clone this repository

```bash
nix-env -f '<nixpkgs>' -iA git
git clone https://github.com/zekurio/nix.git /mnt/etc/nixos
```

Install the system

```bash
nixos-install --root /mnt --no-root-passwd --flake "/mnt/etc/nixos#${HOST}"
```

Unmount and reboot

```bash
umount -Rl /mnt
reboot
```

### Remote deployment with nixos-anywhere

For remote hosts (e.g. `lilith`), use [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) instead:

```bash
nix run github:nix-community/nixos-anywhere -- --flake .#lilith root@<ip>
```

### WSL (tabris)

Follow the [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) setup guide, then apply:

```bash
sudo nixos-rebuild switch --flake .#tabris
```

`tabris` uses Bash as the login shell for WSL compatibility, then `exec`s into Nushell for top-level interactive sessions.
