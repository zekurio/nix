{pkgs, ...}: {
  # Pinned instead of following stateVersion. A major bump moves dataDir
  # and the module would initdb an empty cluster there, so migrate the old
  # one by hand first (README: Upgrade adam's PostgreSQL).
  services.postgresql.package = pkgs.postgresql_18;
}
