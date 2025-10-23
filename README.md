# nix-config

## Machine Configs

```txt
machines
└── nixos
    ├── adam (homelab server)
    └── tabris (wsl config)
```

## User Config

### zekurio

Default wheel user for both systems. Includes a base config that sets up the user, a shell config for fish and other CLI/TUI applications, and a dev config, to setup my preferred development environment.

```txt
modules/home-manager
├── base.nix
├── default.nix
├── dev.nix
└── git.nix
```
## Installation

### adam

#### Prerequisites

- [Latest Minimal ISO](https://nixos.org/download/#nixos-iso)
- A customized flake to fit your needs, you might want to change the user name and password. Also, check the disko.nix file for disk partitioning and formatting.

#### Steps

1. Boot the minimal ISO, become `root`, and connect to the network (configure Wi-Fi or ensure the Ethernet link is up).
2. Enter a shell with Git available: `nix-shell -p git`.
3. Clone this repository and `cd` into it: `git clone https://github.com/your-user/nix-config && cd nix-config`.
4. Wipe and lay out the disks using the provided `disko` recipe: `nix run github:nix-community/disko -- --mode disko machines/nixos/adam/disko.nix`.
5. Mount the target filesystem if `disko` did not do it automatically: `mount /dev/disk/by-label/nixos /mnt` and create `/mnt/boot` as needed.
6. Copy or generate the age key expected by `sops-nix` under `/mnt/etc/sops/age/keys.txt` so secrets can decrypt at boot.
7. Install the system from the flake: `nixos-install --flake .#adam`.
8. Reboot into the new system, then run `nixos-rebuild switch --flake .#adam` to confirm future activations succeed.

### Live Environment Access

Once `adam` is installed, all follow-up changes happen over SSH. Connect with `ssh zekurio@adam.lan` (or adjust the hostname/IP as needed) and escalate with `sudo -i` before running rebuilds. Remote deploys should target the live host, e.g. `nixos-rebuild switch --flake .#adam --target-host zekurio@adam.lan --use-remote-sudo`.
