# AGENTS.md - NixOS Configuration Repository

This repository contains NixOS configurations for a homelab and workstations. See README.md for installation instructions.

## Build Commands

```bash
# Build a specific host configuration (dry-run)
nix flake check --impure
nix build .#nixosConfigurations.adam.config.system.build.toplevel --impure

# Build a specific host
sudo nixos-rebuild switch --flake .#adam

# Build without switching (show what would be done)
nixos-rebuild dry-build --flake .#adam

# Update flake inputs
nix flake update

# Format all nix files with alejandra
nix fmt

# Check formatting without applying
alejandra --check .

# Build a specific package from overlays
nix build .#packages.x86_64-linux.jellyseerr
```

## Secrets Management

Secrets are managed via **sops-nix** with age encryption.

- **Secrets file**: `secrets/{hostname}.yaml`
- **Age key location**: `/var/lib/sops-nix/key.txt` on target systems
- **Creating new secrets**: Use `sops` to edit secrets files

```bash
# Edit secrets (requires age key in environment)
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
sops secrets/adam.yaml
```

## Code Style Guidelines

### General Principles

- Use alejandra for automatic formatting (configured as default formatter)
- Prefer simple, readable configurations over clever abstractions
- Keep modules focused and single-purpose
- Use descriptive names for options, variables, and file paths

### Nix Module Structure

```nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Define local variables at the top of the let block
  domain = "example.com";
  port = 8080;
in {
  # Options defined first
  options.services.example-wrapped = {
    enable = lib.mkEnableOption "Service description";
  };

  # Conditional configuration using mkIf
  config = lib.mkIf config.services.example-wrapped.enable {
    # Actual configuration goes here
  };
}
```

### Naming Conventions

- **Option names**: Use kebab-case (`enable`, `openFirewall`)
- **Variable names**: Use camelCase (`shareUser`, `networkIP`)
- **Module names**: Use kebab-case with descriptive names (`jellyfin.nix`, `qbittorrent.nix`)
- **Host names**: Use lowercase, memorable names (`adam`, `lilith`, `tabris`)
- **Wrapped services**: Use `-wrapped` suffix (`jellyfin-wrapped`, `caddy-wrapper`)

### Attribute Sets

Use shorthand attribute set syntax when possible:

```nix
# Good
boot = {
  kernelParams = ["pcie_aspm=force"];
  kernelModules = ["kvm-amd"];
};

# Avoid
boot.kernelParams = ["pcie_aspm=force"];
boot.kernelModules = ["kvm-amd"];
```

### Imports

- Import modules at the top of the file in the `imports` list
- Order imports alphabetically within each import block
- Group related imports with comments when helpful

```nix
imports = [
  # Hardware
  (modulesPath + "/installer/scan/not-detected.nix")

  # Local modules
  ./disko.nix
  ../default.nix
];
```

### Lists vs Attributes

- Use **lists** for ordered items (`kernelModules`, `allowedTCPPorts`)
- Use **attribute sets** for named configuration (`services`, `environment`)

### Options Pattern

Always define options with `lib.mkEnableOption` or explicit type:

```nix
options.services.my-service = {
  enable = lib.mkEnableOption "My service description";

  # Optional settings with defaults
  port = lib.mkOption {
    type = lib.types.port;
    default = 8080;
    description = "Port to listen on";
  };
};
```

### Conditionals

Use `lib.mkIf` for conditional configuration:

```nix
config = lib.mkIf config.services.example.enable {
  # Configuration here
};
```

Avoid `lib.optional` or `lib.optionals` for NixOS module options; use `mkIf` instead.

### Secrets

- Never commit plain-text secrets
- Use sops-nix for secret management
- Reference secrets via `config.sops.secrets.<name>.path`

```nix
sops = {
  defaultSopsFile = ../../../secrets/adam.yaml;
  age.keyFile = "/var/lib/sops-nix/key.txt";
  secrets = {
    my_secret = { };
  };
};

# Reference in systemd service
systemd.services.my-service = {
  serviceConfig.EnvironmentFile = config.sops.secrets.my_secret.path;
};
```

### System State

Always set `system.stateVersion` and do not change it after initial installation:

```nix
system.stateVersion = "25.05";
```

### Disko Configurations

- Place disko configs in `machines/nixos/{hostname}/disko.nix`
- Use the same partition layout across similar hosts
- Include comments about disk identifiers that need manual updating

## Directory Structure

```
.
├── flake.nix              # Main flake definition
├── README.md              # Installation instructions
├── AGENTS.md              # This file
├── machines/
│   └── nixos/
│       ├── default.nix    # Shared machine modules
│       ├── adam/          # Homelab server config
│       ├── lilith/        # Desktop/workstation config
│       └── tabris/        # WSL config
├── modules/
│   ├── homelab/           # Homelab services
│   │   ├── default.nix
│   │   └── services/      # Individual service modules
│   ├── users/             # User configurations
│   └── virtualization/    # VM/container settings
├── overlays/              # Nixpkgs overlays
├── secrets/               # SOPS encrypted secrets
└── .sops.yaml             # SOPS configuration
```

## Adding New Services

1. Create a new module in `modules/homelab/services/{service}.nix`
2. Use the `-wrapped` pattern with Caddy integration
3. Export the option via `modules/homelab/services/default.nix`
4. Enable in host configuration file
5. Add domain to Caddy virtual host config

## Testing Changes

```bash
# Check flake syntax
nix flake check --impure

# Dry-run rebuild to see what would change
nixos-rebuild dry-build --flake .#adam

# Format code
nix fmt
```

## Common Patterns

### Caddy Reverse Proxy

```nix
services.caddy-wrapper.virtualHosts."servicename" = {
  domain = "service.${domain}";
  reverseProxy = "localhost:${toString port}";
  extraConfig = ''
    # Optional Caddy directives
  '';
};
```

### Systemd Service with Custom User

```nix
systemd.services.my-service = {
  serviceConfig = {
    User = shareUser;
    Group = shareGroup;
    EnvironmentFile = config.sops.secrets.my_secret.path;
  };
};
```

### TMPfiles Rules

```nix
systemd.tmpfiles.rules = [
  "d /var/lib/myapp 2775 ${shareUser} ${shareGroup} -"
];
```
