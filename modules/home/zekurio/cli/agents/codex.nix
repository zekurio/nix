{
  flake.modules.homeManager.zekurio = {
    config,
    lib,
    pkgs,
    ...
  }: let
    kimiCodeApiBaseUrl = "https://api.kimi.com/coding/v1";
    configureCodex = pkgs.writers.writePython3Bin "codex-configure" {
      libraries = [pkgs.python3Packages.tomlkit];
    } (builtins.readFile ./_configure-codex.py);

    setupRouter = pkgs.writeShellApplication {
      name = "codex-router-setup";
      runtimeInputs = [
        pkgs.curl
        pkgs.coreutils
        pkgs.git
        pkgs.nodejs_24
        pkgs.uv
      ];
      text = ''
        installer="$(mktemp)"
        trap 'rm -f "$installer"' EXIT

        curl --fail --silent --show-error --location \
          https://raw.githubusercontent.com/duolahypercho/codex-router/main/install.sh \
          --output "$installer"
        sh "$installer" --target codex --kimi-api-key --auto
        ${configureCodex}/bin/codex-configure

        if [[ "$(uname -s)" == "Darwin" ]]; then
          plist="$HOME/Library/LaunchAgents/io.github.codex-router.plist"
          /usr/bin/plutil -replace EnvironmentVariables.KIMI_API_BASE_URL \
            -string ${lib.escapeShellArg kimiCodeApiBaseUrl} "$plist"
          /bin/launchctl bootout "gui/$(id -u)" "$plist" 2>/dev/null || true
          /bin/launchctl bootstrap "gui/$(id -u)" "$plist"
        else
          systemctl --user daemon-reload
          systemctl --user restart codex-router.service
        fi
      '';
    };
  in {
    home.packages = [
      configureCodex
      setupRouter
    ];

    # The router's Linux service does not copy provider endpoint overrides
    # from its setup process. Keep the Kimi Code subscription endpoint in a
    # systemd drop-in. The setup command patches the equivalent macOS plist.
    xdg.configFile = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      "systemd/user/codex-router.service.d/kimi-code-api.conf".text = ''
        [Service]
        Environment="KIMI_API_BASE_URL=${kimiCodeApiBaseUrl}"
      '';
    };

    # Codex and the router both update files below ~/.codex. Keep these files
    # writable and merge the theme into the existing Codex configuration.
    home.activation.configureCodex = config.lib.dag.entryAfter ["writeBoundary"] ''
      run ${configureCodex}/bin/codex-configure
    '';
  };
}
