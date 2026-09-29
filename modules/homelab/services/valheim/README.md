# Valheim

`adam` runs Valheim with [Grantapher's Valheim Plus](https://github.com/Grantapher/ValheimPlus)
through the [community Valheim container](https://github.com/community-valheim-tools/valheim-server-docker).
The server is named `Die geilsten Gamer e.V. (nicht offiziell)`, is listed in the
community browser and password protected, and creates a world named `Midgard`.

After deploying the NixOS configuration, connect to `10.0.0.2:2456` from the LAN,
or use adam's Tailscale address. Internet players without Tailscale need UDP
ports 2456–2458 forwarded from the router to `10.0.0.2` and must connect using
the public address. There is no HTTP reverse proxy for the game.

Install the matching Grantapher Valheim Plus release on every player's client.
The server enforces the mod version and syncs its configuration to clients.
The host configuration keeps vanilla combat and multiplayer difficulty scaling,
doubles mining ore yields, item stack limits, and mob-drop quantities, and
doubles the slots in wood, personal, reinforced, and blackmetal chests.
Crafting can use chests within 20 metres, measured from the workbench when in
its area. Skill loss on death is disabled; items still go into a recoverable
tombstone under normal world death settings.

Kilns, smelters, and blast furnaces automatically pull fuel and raw materials
from chests within 10 metres and deposit their output into nearby chests.
A coal chest within range of both a kiln and a smelter connects the two.
Production speeds and fuel costs retain their defaults.
Kilns preserve fine and core wood and stop refilling when nearby chests contain
at least 200 coal.

Equipment repairs automatically at the appropriate crafting station and is
re-equipped after swimming. Crop spacing protection prevents planting too
close together. Exploration is shared, and boats and carts appear on the map.
Decorative torches retain fuel; cooking fires still consume it normally.
Portals allow ore, metal, and other normally restricted inventory items.

Change these settings through
`services.homelab.valheim.extraEnvironment`, for example:

```nix
extraEnvironment = {
  VPCFG_Player_enabled = "true";
  VPCFG_Player_baseMaximumWeight = "450";
};
```

The generated password is stored as `valheim_password` in `secrets/adam.yaml`.
Retrieve it locally with:

```sh
sops decrypt --extract '["valheim_password"]' secrets/adam.yaml
```

Use `sops secrets/adam.yaml` to change it. Keep it at least five characters long,
on one line, and different from the server name. The SOPS template supplies it
to the container and restarts the service when the rendered secret changes.

Data on adam:

- `/var/lib/valheim/config/worlds_local`: world saves.
- `/var/lib/valheim/config/valheimplus/valheim_plus.cfg`: mod configuration.
- `/var/lib/valheim/config/backups`: hourly backups, retained for seven days.
- `/var/lib/valheim/data`: downloaded server files and Steam update cache.

Backups are on the same disk as the world. Copy them elsewhere for disk-failure
protection. Stop `podman-valheim.service` before importing or restoring a world.
Match `services.homelab.valheim.worldName` to the imported world name.

Game and mod updates are checked daily at 06:00 in the host's timezone, while
the server is idle. Clients may need a mod update afterward. The container image
uses `latest`; game/mod updates do not refresh the container image itself.

Check startup and mod loading on adam with:

```sh
sudo systemctl status podman-valheim.service
sudo journalctl -u podman-valheim.service -f
sudo podman logs -f valheim
```

The first start downloads the server and mod, so allow time before connecting.
