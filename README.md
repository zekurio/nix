# nix-config

Declarative configuration for my NixOS homelab and macOS workstation, built
with flakes, flake-parts, Home Manager, and nix-darwin.

## Systems

| System | Platform | Role |
| --- | --- | --- |
| [`adam`](modules/hosts/adam) | NixOS · `x86_64-linux` | Homelab server and storage host |
| [`sachiel`](modules/darwin/sachiel) | nix-darwin · `aarch64-darwin` | MacBook Air workstation |

## Homelab services

The inventory below follows the services enabled in
[`adam`](modules/hosts/adam/configuration.nix). It covers the application and
platform workloads managed by this configuration rather than every generated
systemd unit.

### `adam`

#### Applications and automation

| Icon | Service | Description | Category |
| :---: | --- | --- | --- |
| 🎬 | [Alloy](modules/homelab/services/alloy/default.nix) | Self-hosted clip storage and playback server | Media |
| ⚒️ | [Anvil](modules/homelab/services/anvil/default.nix) | Hardware-accelerated media encoding and handoff daemon | Media automation |
| 📅 | [arr-cal-proxy](modules/homelab/services/arr-cal-proxy/default.nix) | Combined Radarr and Sonarr calendar with Jellyfin availability | Media automation |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/beets.svg" alt="beets" width="32" height="32"> | [beets](modules/homelab/services/beets/default.nix) | Music tagging, cleanup, and automatic slskd imports | Media automation |
| 🤖 | [Blitzcrank](modules/homelab/services/blitzcrank/default.nix) | Discord-facing media support and automation agent | Automation |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/configarr.svg" alt="Configarr" width="32" height="32"> | [Configarr](modules/homelab/services/configarr/default.nix) | Scheduled Sonarr and Radarr quality-profile synchronization | Media automation |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/cooler-control.svg" alt="CoolerControl" width="32" height="32"> | [CoolerControl](modules/homelab/services/coolercontrol/default.nix) | Fan and cooling control daemon with a LAN web API | Hardware |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/immich.svg" alt="Immich" width="32" height="32"> | [Immich](modules/homelab/services/immich/default.nix) | Photo and video backup, browsing, and machine-learning search | Media |
| ✉️ | [Inviterr](modules/homelab/services/inviterr/default.nix) | Jellyfin invitations, account management, and password resets | Identity |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/jellyfin.svg" alt="Jellyfin" width="32" height="32"> | [Jellyfin](modules/homelab/services/jellyfin/default.nix) | Movie and television streaming server | Media |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/navidrome.svg" alt="Navidrome" width="32" height="32"> | [Navidrome](modules/homelab/services/navidrome/default.nix) | Personal music streaming server | Media |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/paperless-ngx.svg" alt="Paperless-ngx" width="32" height="32"> | [Paperless-ngx](modules/homelab/services/paperless-ngx/default.nix) | Searchable document archive and workflow system | Documents |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/pocket-id.svg" alt="Pocket ID" width="32" height="32"> | [Pocket ID](modules/homelab/services/pocket-id/default.nix) | Passkey-first OpenID Connect identity provider | Identity |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/prowlarr.svg" alt="Prowlarr" width="32" height="32"> | [Prowlarr](modules/homelab/services/prowlarr/default.nix) | Indexer manager shared by the media automation stack | Media automation |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/radarr.svg" alt="Radarr" width="32" height="32"> | [Radarr](modules/homelab/services/radarr/default.nix) | Movie collection manager | Media automation |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/sabnzbd.svg" alt="SABnzbd" width="32" height="32"> | [SABnzbd](modules/homelab/services/sabnzbd/default.nix) | Usenet download client | Downloads |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/seerr.svg" alt="Seerr" width="32" height="32"> | [Seerr](modules/homelab/services/seerr/default.nix) | Media discovery and request management | Requests |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/slskd.svg" alt="slskd" width="32" height="32"> | [slskd](modules/homelab/services/slskd/default.nix) | Web-based Soulseek client | Downloads |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/sonarr.svg" alt="Sonarr" width="32" height="32"> | [Sonarr](modules/homelab/services/sonarr/default.nix) | Television collection manager | Media automation |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/vaultwarden.svg" alt="Vaultwarden" width="32" height="32"> | [Vaultwarden](modules/homelab/services/vaultwarden/default.nix) | Bitwarden-compatible password manager | Security |

#### Platform services

| Icon | Service | Description | Category |
| :---: | --- | --- | --- |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/caddy.svg" alt="Caddy" width="32" height="32"> | [Caddy](modules/homelab/services/caddy/default.nix) | Reverse proxy, automatic TLS, and Cloudflare DNS integration | Networking |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/oauth2-proxy.svg" alt="OAuth2 Proxy" width="32" height="32"> | [OAuth2 Proxy](modules/homelab/services/oauth2-proxy/default.nix) | Forward-auth gateway protecting private web applications | Identity |
| 📣 | [Avahi](modules/homelab/services/media-share/default.nix) | Local network discovery for SMB shares | Networking |
| 🗂️ | [NFS](modules/homelab/services/media-share/default.nix) | NFSv4 exports for shared files and media | Storage |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/podman.svg" alt="Podman" width="32" height="32"> | [Podman](modules/virtualization.nix) | Rootless OCI container runtime and Docker-compatible socket | Virtualization |
| 🗄️ | [Samba](modules/homelab/services/media-share/default.nix) | SMB file and media shares | Storage |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/tailscale.svg" alt="Tailscale" width="32" height="32"> | [Tailscale](modules/hosts/adam/tailscale.nix) | Encrypted remote access to the homelab network | Networking |

Application logos are served by [selfh.st/icons](https://selfh.st/icons/).
Custom services and platform components without a catalog entry retain a small
emoji fallback.

`sachiel` is a workstation and does not host homelab workloads. Its
configuration manages Nix, shell and CLI tooling, Git/SSH, and Home Manager
applications.

## Repository layout

```text
modules/
├── darwin/              # nix-darwin systems
├── home/                # Home Manager configuration
├── homelab/services/    # Reusable homelab service modules
├── hosts/               # NixOS host configuration
└── nixpkgs/             # Shared nixpkgs configuration and overlays
secrets/                 # SOPS-encrypted host secrets
```

## Bootstrap macOS / nix-darwin

On a fresh macOS install, install upstream multi-user Nix—not the Determinate
installer—then let nix-darwin take over:

```bash
sh <(curl -L https://nixos.org/nix/install)
```

Open a new shell, clone this repository to `~/Git/nix`, and bootstrap the first
generation:

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
  run nix-darwin/master#darwin-rebuild -- \
  switch --flake path:/Users/zekurio/Git/nix#sachiel
```

Subsequent rebuilds can use `darwin-rebuild` directly. Keep the `path:` prefix
so the root activation step treats the checkout as a plain path:

```bash
sudo darwin-rebuild switch --flake path:/Users/zekurio/Git/nix#sachiel
```

## Install NixOS

Boot into the NixOS installer and enable flakes:

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Partition and mount the drives using [disko](https://github.com/nix-community/disko):

```bash
HOST=adam
DISK='/dev/disk/by-id/<your-disk-id>'

curl -o /tmp/disko.nix \
  "https://raw.githubusercontent.com/zekurio/nix/main/modules/hosts/${HOST}/disko.nix"
sed -i "s|device = \"/dev/disk/by-id/[^\"]*\"|device = \"${DISK}\"|" /tmp/disko.nix
nix --experimental-features "nix-command flakes" run github:nix-community/disko \
  -- -m destroy,format,mount /tmp/disko.nix
```

Install Git, clone the repository, and install the system:

```bash
nix-env -f '<nixpkgs>' -iA git
git clone https://github.com/zekurio/nix.git /mnt/etc/nixos
nixos-install --root /mnt --no-root-passwd --flake "/mnt/etc/nixos#${HOST}"
```

Unmount and reboot:

```bash
umount -Rl /mnt
reboot
```

## Bootstrap secrets on `adam`

`adam` decrypts its SOPS secrets with an age key at
`/var/lib/sops-nix/key.txt`. The key is deliberately not generated on the host,
so copy it into place before or immediately after the first rebuild:

```bash
sudo install -Dm600 -o root -g root key.txt /var/lib/sops-nix/key.txt
```

Without this key, secret-dependent services cannot activate. The host's public
age recipient is stored in [`.sops.yaml`](.sops.yaml).
