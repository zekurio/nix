# nix-config

Nix configurations for my NixOS hosts and macOS.

## Hosts

| Host | Type | Description |
|------|------|-------------|
| `adam` | NixOS | Homelab server |
| `sachiel` | nix-darwin | MacBook Air |

## Bootstrap runbook (macOS / nix-darwin)

On a fresh macOS install, install upstream (vanilla) multi-user Nix — **not** the
Determinate installer — then let nix-darwin take over:

```bash
sh <(curl -L https://nixos.org/nix/install)
```

Open a new shell, clone this repo to `~/Git/nix`, then bootstrap the first
generation (`darwin-rebuild` isn't on `PATH` yet, and flakes aren't enabled on a
fresh upstream install):

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
    run nix-darwin/master#darwin-rebuild -- switch --flake path:/Users/zekurio/Git/nix#sachiel
```

Subsequent rebuilds use `darwin-rebuild` directly (see below).

The `sachiel` configuration manages Nix, shell and CLI tooling, Git/SSH, and
Home Manager configuration for Feishin, Ghostty, Vesktop, and Zed. Desktop
applications are installed natively; LLM agents come from `llm-agents.nix`.

## Rebuild runbook (nix-darwin)

On macOS, use `path:` so the root activation step reads the checkout as a
plain path instead of trying to treat Michael's Git working tree as root-owned:

```bash
sudo darwin-rebuild switch --flake path:/Users/zekurio/Git/nix#sachiel
```

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


## Secrets bootstrap (sops-nix, adam only)

`adam` decrypts its sops secrets with an age key at
`/var/lib/sops-nix/key.txt`. The key is deliberately **not** generated on the
host (`generateKey = false`), so a fresh install has one manual step: copy the
host's private key into place before (or right after) the first rebuild:

```bash
sudo install -Dm600 -o root -g root key.txt /var/lib/sops-nix/key.txt
```

Without it, every secret-dependent service fails to activate. The host's
public key (recipient) lives in `.sops.yaml`.
