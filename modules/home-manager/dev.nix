{
  lib,
  config,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.homeManager.dev;
in
{
  options.modules.homeManager.dev = {
    enable =
      mkEnableOption "Development tools and languages"
      // {
        default = false;
      };
  };

  config = mkIf cfg.enable {
    home-manager.users.zekurio = { pkgs, ... }: {
      home.packages = with pkgs; [
        # Node.js ecosystem
        nodejs_22
        pnpm
        bun

        # Go
        go
        golangci-lint

        # Rust
        rustup

        # Build tools
        pkg-config
        cmake
        gnumake

        # Python, yuck
        uv

        # Development utilities
        curl
        jq
        yq
        httpie
        postgresql
      ];
    };
  };
}
