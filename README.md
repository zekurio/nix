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
