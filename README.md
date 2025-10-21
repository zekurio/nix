# nix-config

These notes cover how to reinstall the `adam` host from a NixOS live environment by reusing the declarative `machines/nixos/adam/disko.nix` storage layout and this flake.

- Update `machines/nixos/adam/disko.nix` so `disko.devices.disk.main.device` matches the target drive (`/dev/nvme0n1`, `/dev/sda`, …) before you deploy.
- Boot the target machine with the NixOS live ISO, connect it to the network, and discover its address (`ip a`).
- On the live ISO console, set a temporary password for the `nixos` user so SSH will accept the login: `sudo passwd nixos`. Without a password or preloaded `authorized_keys`, the OpenSSH server refuses the connection.
- Start the SSH daemon if it is not already running: `sudo systemctl start sshd`.
- From your workstation, connect into the live session with agent forwarding so the forwarded key can clone this repo: `ssh -A nixos@<live-ip>`. Elevate to root with `sudo -i`.
- Enter a shell that provides Git (the minimal ISO does not have it in `$PATH`): `nix shell nixpkgs#git -c $SHELL` (or `nix-shell -p git` if you prefer).
- Fetch the configuration via SSH using your forwarded key: `git clone git@github.com:<account>/nix-config /root/nix-config && cd /root/nix-config`.
- Install the system using nixos-anywhere:
  ```bash
  nix run github:nix-community/nixos-anywhere -- localhost --flake .#adam --extra-nixos-install-args '--no-root-passwd'
  ```
  nixos-anywhere handles the partitioning using the Disko configuration in the flake, mounts the root filesystem at `/mnt`, and runs `nixos-install` to copy the system and enable the flake.
- After the installer finishes, unmount (`umount -R /mnt`), reboot, and SSH to the freshly provisioned host: `ssh root@<adam-ip>`.

If you need to re-run the install, reboot back into the live ISO, SSH in again, and repeat the cloning and nixos-anywhere steps.

## WSL Setup (tabris)

The `tabris` WSL configuration includes Windows SSH Agent integration, allowing you to use SSH keys managed by Windows (including hardware keys) seamlessly in WSL.

### Prerequisites

1. **Install npiperelay on Windows** (required for SSH agent bridge):
   ```powershell
   # Using Scoop (recommended)
   scoop install npiperelay
   ```

2. **Enable Windows SSH Agent** (PowerShell as Administrator):
   ```powershell
   Set-Service ssh-agent -StartupType Automatic
   Start-Service ssh-agent
   ```

3. **Add your SSH key to Windows SSH Agent**:
   ```powershell
   ssh-add $env:USERPROFILE\.ssh\id_ed25519
   ssh-add -l  # Verify keys are loaded
   ```

### Building and Installing

1. **Update flake and build the WSL tarball**:
   ```bash
   nix flake update
   nix build .#nixosConfigurations.tabris.config.system.build.tarball
   ```

2. **Import into WSL** (from PowerShell on Windows):
   ```powershell
   mkdir $env:USERPROFILE\WSL\NixOS-tabris
   wsl --import NixOS-tabris $env:USERPROFILE\WSL\NixOS-tabris .\result\tarball\nixos-wsl-installer.tar.gz
   wsl -d NixOS-tabris
   ```

3. **Verify SSH agent integration** (inside WSL):
   ```bash
   systemctl --user status ssh-agent-bridge
   ssh-add -l  # Should show your Windows SSH keys
   ```

### Updating

After making configuration changes:
```bash
sudo nixos-rebuild switch --flake /path/to/nix-config#tabris
```

The SSH agent bridge service automatically detects npiperelay from Scoop, WinGet, or Chocolatey installations and creates a socket at `/mnt/wsl/ssh-agent.sock` that bridges to the Windows SSH Agent.
