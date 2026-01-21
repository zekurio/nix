# nix-config

NixOS configurations for my homelab

## Hosts

| Host | Description |
|------|-------------|
| `adam` | Homelab server |

## Installation runbook (NixOS)

Boot into the NixOS installer and enable flakes

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Partition and mount the drives using [disko](https://github.com/nix-community/disko)

```bash
DISK='/dev/disk/by-id/ata-Samsung_SSD_850_EVO_250GB_XXXXX'

curl https://raw.githubusercontent.com/zekurio/nix/main/machines/nixos/adam/disko.nix \
    -o /tmp/disko.nix
sed -i "s|ata-Samsung_SSD_850_EVO_250GB_S2R6NX1JB55464R|${DISK#/dev/disk/by-id/}|" /tmp/disko.nix
nix --experimental-features "nix-command flakes" run github:nix-community/disko \
    -- -m destroy,format,mount /tmp/disko.nix
```

Install git

```bash
nix-env -f '<nixpkgs>' -iA git
```

Clone this repository

```bash
mkdir -p /mnt/etc/nixos
git clone https://github.com/zekurio/nix.git /mnt/etc/nixos
```

Install the system

```bash
nixos-install \
--root "/mnt" \
--no-root-passwd \
--flake "git+file:///mnt/etc/nixos#hostname" # adam, etc.
```

Unmount the filesystems

```bash
umount -Rl "/mnt"
```

Reboot

```bash
reboot
```
