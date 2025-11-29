# nix-config

## Quick Start

### Check Everything's Valid
```bash
nix flake check
```

### Build Without Applying
```bash
nixos-rebuild build --flake .#adam
```
Good for testing changes before committing.

### Apply Locally
```bash
nixos-rebuild switch --flake .#<host>
```

### Apply Remotely
```bash
nixos-rebuild switch --flake .#adam --target-host root@adam.lan --use-remote-sudo
```

## Fresh Install with nixos-anywhere

Got a new machine? Here's how to bootstrap it from scratch.

### 1. Prep the Target
1. Boot from a NixOS minimal ISO
2. Get networking up and start SSH: `systemctl start sshd`
3. Set a temp root password (`passwd`) or add your SSH key
4. Make sure `machines/nixos/<host>/disko.nix` matches your disk layout

### 2. Fire Away
```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#<host> \
  --target-host root@<ip-or-hostname> \
  --build-on-remote \
  --no-reboot
```

### 3. Set Up Secrets & Reboot
```bash
ssh root@<host> 'install -m 700 -d /var/lib/sops-nix'
scp ~/.config/sops/age/keys.txt root@<host>:/var/lib/sops-nix/key.txt
ssh root@<host> 'chmod 600 /var/lib/sops-nix/key.txt'
ssh root@<host> reboot
```

Then confirm it works:
```bash
nixos-rebuild switch --flake .#<host> --target-host root@<host> --use-remote-sudo
```

## WSL Setup (tabris)

Using NixOS inside WSL? Here's how:

### Create the Distro
```bash
nix build .#nixosConfigurations.tabris.config.system.build.tarball
wsl --import tabris "$HOME/WSL/tabris" result/nixos-wsl.tar.gz --version 2
```

### Update Later
```bash
sudo nixos-rebuild switch --flake .#tabris
```
There's also a `rebuild-tabris` alias for convenience.
