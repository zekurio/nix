# nix-config

NixOS configurations for my current systems.

## Hosts

| Host | Description |
|------|-------------|
| `adam` | Homelab server |
| `tabris` | WSL environment |

## Installation runbook (NixOS)

Boot into the NixOS installer and enable flakes

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Partition and mount the drives using [disko](https://github.com/nix-community/disko)

```bash
HOST=adam
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

## WSL SSH agent bridge

`tabris` bridges the Windows OpenSSH agent into WSL at `/mnt/wsl/ssh-agent.sock`.
Keep the Windows OpenSSH Authentication Agent service running; the WSL side uses
the packaged `wsl2-ssh-agent` bridge.
