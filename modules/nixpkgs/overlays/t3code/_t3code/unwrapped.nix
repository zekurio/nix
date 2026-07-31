{
  cacert,
  cctools,
  copyDesktopItems,
  electron_41,
  fetchFromGitHub,
  fetchPnpmDeps,
  installShellFiles,
  lib,
  libicns,
  makeBinaryWrapper,
  makeDesktopItem,
  nix-update-script,
  node-gyp,
  nodejs,
  pnpm_11,
  pnpmBuildHook,
  pnpmConfigHook,
  python3,
  stdenv,
  writeDarwinBundle,
  xcbuild,
}:
stdenv.mkDerivation (
  finalAttrs: let
    appName = "T3 Code (Alpha)";
    electron = electron_41;
    pnpm = pnpm_11;
    desktopIcon =
      if stdenv.hostPlatform.isDarwin
      then "assets/prod/black-macos-1024.png"
      else "assets/prod/black-universal-1024.png";
  in {
    pname = "t3code-unwrapped";
    version = "0.0.31";
    strictDeps = true;
    __structuredAttrs = true;

    src = fetchFromGitHub {
      owner = "pingdotgg";
      repo = "t3code";
      tag = "v${finalAttrs.version}";
      hash = "sha256-KFGwgAIOqHbi3enmNAPt95+UAakm6pmClPK1nYNoOlk=";
    };

    postPatch = ''
      substituteInPlace apps/web/vite.config.ts \
        --replace-fail 'const host = explicitHost || "localhost";' \
                       'const host = explicitHost || "127.0.0.1";'
    '';

    nativeBuildInputs =
      [
        installShellFiles
        makeBinaryWrapper
        node-gyp
        nodejs
        python3
        pnpmConfigHook
        pnpmBuildHook
        pnpm
        cacert
      ]
      ++ lib.optionals stdenv.hostPlatform.isLinux [copyDesktopItems]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [
        cctools.libtool
        libicns
        writeDarwinBundle
        xcbuild
      ];

    pnpmWorkspaces = [
      # Include transitive workspace dependencies such as contracts and shared.
      "@t3tools/monorepo"
      "t3..."
      "@t3tools/desktop..."
      "@t3tools/scripts..."
    ];

    pnpmDeps = fetchPnpmDeps {
      inherit pnpm;
      inherit
        (finalAttrs)
        pname
        version
        src
        pnpmWorkspaces
        ;

      fetcherVersion = 4;
      hash = "sha256-6tuT9MS+PIMV0PFiw1q6vtZyk3yFB5Y4yHgWohMJczs=";
    };

    preBuild = ''
      # pnpm 11 otherwise treats the version rewrite as dependency drift and
      # performs an unrequested second install with lifecycle scripts enabled.
      export pnpm_config_verify_deps_before_run=false

      node scripts/update-release-package-versions.ts ${finalAttrs.version}

      export npm_config_nodedir=${nodejs}
      export ELECTRON_SKIP_BINARY_DOWNLOAD=1
      # vp config needs Git, so exclude the root workspace from this rebuild.
      pnpm rebuild --pending "''${pnpmInstallFlags[@]}" --filter '!@t3tools/monorepo'
    '';

    pnpmBuildScript = "build:desktop";

    postBuild = ''
      pnpm vp cache clean
    '';

    # Dependencies vendor prebuilt native artifacts for several platforms.
    # Some are statically linked, so patchelf and the tmpdir audit are invalid.
    dontPatchELF = true;
    noAuditTmpdir = true;

    installPhase =
      ''
        runHook preInstall

        mkdir --parents "$out"/libexec/t3code/apps/desktop "$out"/libexec/t3code/apps/server
        cp --recursive --no-preserve=mode node_modules "$out"/libexec/t3code
        cp --recursive --no-preserve=mode apps/server/{node_modules,dist} "$out"/libexec/t3code/apps/server
        cp --recursive --no-preserve=mode \
          apps/desktop/{package.json,node_modules,dist-electron} \
          "$out"/libexec/t3code/apps/desktop

        mkdir --parents "$out"/libexec/t3code/apps/desktop/prod-resources
        install --mode=444 ${desktopIcon} \
          "$out"/libexec/t3code/apps/desktop/prod-resources/icon.png

        find "$out"/libexec/t3code -xtype l -delete

        makeWrapper ${lib.getExe nodejs} "$out"/bin/t3 \
          --add-flags "$out"/libexec/t3code/apps/server/dist/bin.mjs

        makeWrapper ${lib.getExe electron} "$out"/bin/t3code-desktop \
          --add-flags "$out"/libexec/t3code/apps/desktop \
          --inherit-argv0
      ''
      + lib.optionalString stdenv.hostPlatform.isDarwin ''
        # node-pty tries to chmod this helper at runtime, but the Nix store is
        # immutable by then.
        find "$out"/libexec/t3code \
          -path '*/node-pty/prebuilds/darwin-*/spawn-helper' \
          -exec chmod 755 {} +

        mkdir --parents "$out/Applications/${appName}.app/Contents/"{MacOS,Resources}
        png2icns \
          "$out/Applications/${appName}.app/Contents/Resources/t3code.icns" \
          ${desktopIcon}

        # writeDarwinBundle has no shebang, so invoke it through the shell.
        ${stdenv.shell} ${lib.getExe writeDarwinBundle} \
          "$out" "${appName}" t3code-desktop t3code
      ''
      + ''
        mkdir --parents "$out"/share/icons/hicolor/scalable/apps
        install --mode=444 ${desktopIcon} "$out"/share/icons/t3code.png
        install --mode=444 assets/prod/logo.svg \
          "$out"/share/icons/hicolor/scalable/apps/t3code.svg

        runHook postInstall
      '';

    postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
      for shell in bash fish zsh; do
        installShellCompletion --cmd t3 --"$shell" <("$out/bin/t3" --completions "$shell")
      done
    '';

    desktopItems = [
      (makeDesktopItem {
        name = "t3code";
        desktopName = appName;
        comment = "Minimal web GUI for coding agents";
        exec = "t3code-desktop %U";
        terminal = false;
        icon = "t3code";
        startupWMClass = "t3code";
        categories = ["Development"];
      })
    ];

    passthru.updateScript = nix-update-script {
      attrPath = "t3code";
      extraArgs = [
        "--flake"
        "--use-github-releases"
      ];
    };

    meta = {
      description = "Minimal web GUI for coding agents";
      homepage = "https://t3.codes";
      downloadPage = "https://t3.codes/download";
      changelog = "https://github.com/pingdotgg/t3code/releases/tag/${finalAttrs.src.tag}";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [
        iamanaws
        qweered
      ];
      mainProgram = "t3code-desktop";
      inherit (nodejs.meta) platforms;
    };
  }
)
