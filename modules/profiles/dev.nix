{ lib
, pkgs
, config
, ...
}:
let
  inherit
    (lib)
    hasAttrByPath
    mkAfter
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.profiles.dev;

  basePackages = pkgs':
    with pkgs'; [
      age
      bat
      btop
      eza
      envsubst
      fastfetch
      git
      jq
      nil
      nixd
      sops
      zellij
    ];
in
{
  options.profiles.dev = {
    enable =
      mkEnableOption "Development profile powered by Home Manager"
      // {
        default = true;
      };

    user = mkOption {
      type = types.str;
      default = "zekurio";
      description = "Primary user account managed by the development profile.";
    };

    stateVersion = mkOption {
      type = types.str;
      default = "25.05";
      description = "Home Manager stateVersion for the managed user.";
    };
  };

  config =
    mkIf cfg.enable {
      assertions = [
        {
          assertion = hasAttrByPath [ cfg.user ] config.users.users;
          message = "profiles.dev.user must reference an existing entry in users.users";
        }
      ];

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
      };

      home-manager.users.${cfg.user} = { pkgs, ... }: {
        home = {
          username = cfg.user;
          homeDirectory = "/home/${cfg.user}";
          stateVersion = cfg.stateVersion;
          enableNixpkgsReleaseCheck = false;
          packages = basePackages pkgs;
        };

        programs = {
          direnv = {
            enable = true;
            nix-direnv.enable = true;
          };

          eza = {
            enable = true;
            extraOptions = [
              "--group-directories-first"
              "--icons=auto"
            ];
          };

          fish = {
            enable = true;
            interactiveShellInit = ''
              set -g fish_greeting
            '';
            plugins = [ ];
          };

          starship = {
            enable = true;
            enableFishIntegration = true;
            settings = builtins.fromTOML ''
              [aws]
              symbol = " "

              [buf]
              symbol = " "

              [bun]
              symbol = " "

              [c]
              symbol = " "

              [cpp]
              symbol = " "

              [cmake]
              symbol = " "

              [conda]
              symbol = " "

              [crystal]
              symbol = " "

              [dart]
              symbol = " "

              [deno]
              symbol = " "

              [directory]
              read_only = " 󰌾"

              [docker_context]
              symbol = " "

              [elixir]
              symbol = " "

              [elm]
              symbol = " "

              [fennel]
              symbol = " "

              [fortran]
              symbol = " "

              [fossil_branch]
              symbol = " "

              [gcloud]
              symbol = " "

              [git_branch]
              symbol = " "

              [git_commit]
              tag_symbol = '  '

              [golang]
              symbol = " "

              [gradle]
              symbol = " "

              [guix_shell]
              symbol = " "

              [haskell]
              symbol = " "

              [haxe]
              symbol = " "

              [hg_branch]
              symbol = " "

              [hostname]
              ssh_symbol = " "

              [java]
              symbol = " "

              [julia]
              symbol = " "

              [kotlin]
              symbol = " "

              [lua]
              symbol = " "

              [memory_usage]
              symbol = "󰍛 "

              [meson]
              symbol = "󰔷 "

              [nim]
              symbol = "󰆥 "

              [nix_shell]
              symbol = " "

              [nodejs]
              symbol = " "

              [ocaml]
              symbol = " "

              [os.symbols]
              Alpaquita = " "
              Alpine = " "
              AlmaLinux = " "
              Amazon = " "
              Android = " "
              AOSC = " "
              Arch = " "
              Artix = " "
              CachyOS = " "
              CentOS = " "
              Debian = " "
              DragonFly = " "
              Emscripten = " "
              EndeavourOS = " "
              Fedora = " "
              FreeBSD = " "
              Garuda = "󰛓 "
              Gentoo = " "
              HardenedBSD = "󰞌 "
              Illumos = "󰈸 "
              Kali = " "
              Linux = " "
              Mabox = " "
              Macos = " "
              Manjaro = " "
              Mariner = " "
              MidnightBSD = " "
              Mint = " "
              NetBSD = " "
              NixOS = " "
              Nobara = " "
              OpenBSD = "󰈺 "
              openSUSE = " "
              OracleLinux = "󰌷 "
              Pop = " "
              Raspbian = " "
              Redhat = " "
              RedHatEnterprise = " "
              RockyLinux = " "
              Redox = "󰀘 "
              Solus = "󰠳 "
              SUSE = " "
              Ubuntu = " "
              Unknown = " "
              Void = " "
              Windows = "󰍲 "

              [package]
              symbol = "󰏗 "

              [perl]
              symbol = " "

              [php]
              symbol = " "

              [pijul_channel]
              symbol = " "

              [pixi]
              symbol = "󰏗 "

              [python]
              symbol = " "

              [rlang]
              symbol = "󰟔 "

              [ruby]
              symbol = " "

              [rust]
              symbol = "󱘗 "

              [scala]
              symbol = " "

              [status]
              symbol = " "

              [swift]
              symbol = " "

              [xmake]
              symbol = " "

              [zig]
              symbol = " "
            '';
          };

          git = {
            enable = true;
            settings = {
              user.name = "Michael Schwieger";
              user.email = "git@zekurio.xyz";
              init.defaultBranch = "main";
              pull.rebase = true;
              rebase.autoStash = true;
              gpg.format = "ssh";
              gpg.ssh.program = "${pkgs.openssh}/bin/ssh-keygen";
              user.signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCcQoZiY9wkJ+U93isE8B3CKLmzL7TPzVh3ugE1WPJq";
              commit.gpgSign = true;
            };
          };

          ssh = {
            enable = true;
            enableDefaultConfig = false;
            matchBlocks."*".compression = true;
          };
        };
      };

      environment.systemPackages = mkAfter [
        pkgs.gh
        pkgs.unstable.codex
        pkgs.unstable.opencode
      ];
    };
}
