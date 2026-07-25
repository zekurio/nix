# Lidarr's plugin system — the System → Plugins page and the loader that lets a
# plugin register a first-party download client, such as the slskd/Soulseek one
# — exists only on upstream's `plugins` branch. `master`, which nixpkgs
# packages, carries no plugin loader at all, so Soulseek can never appear as a
# real download client there.
#
# The branch forks from v3.1.0.4875, exactly the release nixpkgs builds, and is
# 11 commits ahead of it. None of those commits touch yarn.lock, package.json,
# global.json, src/NuGet.config or any PackageReference — the single .csproj
# change only marks the Lidarr.Common ProjectReference `Private=false` so
# plugins resolve it from the host's load context. The vendored NuGet lockfile
# and the yarn offline-cache hash therefore still describe this tree, and only
# the source, the version and the branch stamp need overriding.
#
# Upstream cuts no release or tag from the branch, so it is pinned by commit.
#
# Switching is one-way for the database: the branch adds migrations 043
# (flexible delay profiles) and 046 (blocklist protocol conversion) that master
# never had. FluentMigrator records applied versions individually, so both run
# on first start even though the database is already past 080, and master
# cannot read the reshaped tables afterwards. Back up /var/lib/lidarr before the
# first switch.
#
# Drop this file if plugin support ever lands on master.
let
  rev = "e42a7ca4fd633e021d69da7daa0368b870b0282e";

  # The branch carries no version of its own — src/Directory.Build.props holds
  # only the CI placeholder 10.0.0.* — but upstream's pipeline publishes this
  # exact commit to the `plugins` update channel as 3.1.2.4913 (Azure build
  # 4872, stamped 2026-01-18T18:25:33, 34 seconds after the commit). Reuse that
  # number: Lidarr gates plugin compatibility on BuildInfo.Version, and a lower
  # one makes the update check offer this build to itself.
  version = "3.1.2.4913";

  # Lidarr takes its reported version and branch from these two assembly
  # attributes, which nixpkgs stamps to match the master release it builds.
  restampedProperties = [
    "AssemblyVersion"
    "AssemblyConfiguration"
  ];

  overlay = final: prev: let
    src = final.applyPatches {
      src = final.fetchFromGitHub {
        owner = "Lidarr";
        repo = "Lidarr";
        inherit rev;
        hash = "sha256-vjLoMU7Ow9rFFcZjCUvqoKZnrmg3TeB8Cqh1nSF8shM=";
      };
      # dotnet only honours the capitalised name at the restore root.
      postPatch = "mv src/NuGet.config NuGet.Config";
    };
  in {
    lidarr = prev.lidarr.overrideAttrs (old: {
      inherit src version;

      # yarn.lock is byte-identical to v3.1.0.4875, so upstream's hash still
      # holds. Refetch against this source anyway, otherwise the master tarball
      # is realised purely to read one file out of it.
      yarnOfflineCache = final.fetchYarnDeps {
        yarnLock = "${src}/yarn.lock";
        hash = "sha256-Jq2O7gvB+PKcz6uDBMg7ox6/Bu+pikXH6JGuLfKG5fI=";
      };

      dotnetFlags = let
        isRestamped = flag:
          prev.lib.any (property: prev.lib.hasPrefix "--property:${property}=" flag) restampedProperties;
        kept = prev.lib.filter (flag: !isRestamped flag) old.dotnetFlags;
        dropped = builtins.length old.dotnetFlags - builtins.length kept;
      in
        prev.lib.throwIf (dropped != builtins.length restampedProperties) ''
          lidarr overlay: expected upstream to stamp ${toString (builtins.length restampedProperties)} of
          ${builtins.concatStringsSep ", " restampedProperties} but matched ${toString dropped}, so this
          build would report the wrong version or branch. Re-check modules/nixpkgs/overlays/lidarr.
        ''
        (kept
          ++ [
            "--property:AssemblyVersion=${version}"
            "--property:AssemblyConfiguration=plugins"
          ]);

      meta =
        old.meta
        // {
          # The upstream tag belongs to master and does not describe this build.
          changelog = "https://github.com/Lidarr/Lidarr/commits/plugins";
        };
    });
  };
in {
  # Only adam runs Lidarr; the darwin base is deliberately untouched.
  flake.modules.nixos.base.nixpkgs.overlays = [overlay];
}
