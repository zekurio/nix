{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    dataDir = config.services.jellyfin.dataDir;
    backupDir = "/var/backup/jellyfin";
    backupArchive = "${backupDir}/jellyfin-10.11.11-pre-12.0-rc7.tar.zst";
  in {
    config = lib.mkIf config.services.homelab.jellyfin.enable {
      systemd.tmpfiles.rules = [
        "d ${backupDir} 0700 jellyfin jellyfin - -"
      ];

      # preStart runs after the old process has stopped, so SQLite and the rest
      # of the data directory are consistent. Keep this one-shot archive until
      # we are certain that Jellyfin 12's migrations do not need rolling back.
      systemd.services.jellyfin = {
        preStart = ''
          backup=${lib.escapeShellArg backupArchive}
          if [[ ! -e "$backup" ]]; then
            temporary="$backup.tmp"
            rm -f "$temporary"
            trap 'rm -f "$temporary"' EXIT

            set -o pipefail
            ${pkgs.gnutar}/bin/tar \
              --create \
              --file=- \
              --directory=${lib.escapeShellArg (builtins.dirOf dataDir)} \
              ${lib.escapeShellArg (builtins.baseNameOf dataDir)} \
              | ${pkgs.zstd}/bin/zstd --threads=0 -10 --stdout >"$temporary"

            ${pkgs.zstd}/bin/zstd --test "$temporary"
            ${pkgs.gnutar}/bin/tar \
              --list \
              --file="$temporary" \
              --use-compress-program=${pkgs.zstd}/bin/zstd \
              >/dev/null
            chmod 0600 "$temporary"
            mv --no-target-directory "$temporary" "$backup"
            trap - EXIT
          fi
        '';
        serviceConfig = {
          ReadWritePaths = [backupDir];
          # Compressing the current 2.3 GiB data directory may exceed the
          # module's 15-second startup timeout.
          TimeoutStartSec = "15min";
        };
      };
    };
  };
}
