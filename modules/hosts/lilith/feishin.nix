{
  lib,
  pkgs,
  ...
}: let
  # Feishin builds mpris:trackid from the music server's opaque song ID and
  # only strips the first hyphen. Aurral IDs look like
  # song:recording:<uuid>, so the resulting D-Bus object path is invalid and
  # dbus-broker disconnects Feishin as soon as it publishes track metadata.
  # Sanitizing every segment keeps the bus connection alive.
  feishin =
    lib.warnIf (pkgs.feishin.version != "1.17.0")
    "modules/hosts/lilith/feishin.nix: Feishin is past 1.17.0. Check whether upstream sanitizes mpris:trackid and drop this patch."
    (pkgs.feishin.overrideAttrs (old: {
      patches = (old.patches or []) ++ [./feishin-mpris-trackid.patch];
    }));
in {
  environment.systemPackages = [feishin];
}
