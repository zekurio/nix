{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.newt;

    # "127.0.0.1:8081" -> { hostname = "127.0.0.1"; port = 8081; }
    splitTarget = target: let
      parts = lib.splitString ":" target;
    in {
      hostname = builtins.head parts;
      port = lib.toInt (builtins.elemAt parts 1);
    };
  in {
    options.services.homelab.newt = {
      enable = lib.mkEnableOption ''
        the Newt tunnel client that registers this host as a site on the
        ramiel Pangolin edge. Newt dials out over WireGuard in user space,
        so no inbound port has to be opened for it
      '';

      endpoint = lib.mkOption {
        type = lib.types.str;
        default = "https://pangolin.zekurio.me";
        description = "Pangolin dashboard this site registers with.";
      };

      resources = lib.mkOption {
        default = {};
        description = ''
          Resources this site publishes through Pangolin, rendered into the
          blueprint Newt applies on every start. The blueprint is a continuous
          source of truth: edits made in the Pangolin dashboard to these
          resources are overwritten on the next apply, so declare them here.

          Deliberately shaped like services.homelab.caddy.virtualHosts so a
          service can be moved from the Caddy vhost on adam to the Pangolin
          edge without rewriting its module. Both may coexist during a
          migration — DNS decides which one actually serves the domain, which
          makes a cutover (and its rollback) a DNS change alone.
        '';
        type = lib.types.attrsOf (
          lib.types.submodule (
            {name, ...}: {
              options = {
                displayName = lib.mkOption {
                  type = lib.types.str;
                  default = name;
                  description = "Name shown in the Pangolin dashboard.";
                };

                domain = lib.mkOption {
                  type = lib.types.str;
                  description = "Full public domain, e.g. costs.schnitzelflix.xyz.";
                };

                target = lib.mkOption {
                  type = lib.types.str;
                  example = "127.0.0.1:8081";
                  description = ''
                    Backend address on this host, mirroring the reverseProxy
                    option of a Caddy virtual host.
                  '';
                };

                sso = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = ''
                    Gate the resource behind Pangolin's own SSO. This is the
                    edge-side replacement for a Caddy forwardAuth entry; leave
                    it off for services that do their own authentication.
                  '';
                };

                ssoRoles = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [];
                  example = ["Admin"];
                  description = ''
                    Restrict the resource to these Pangolin roles. Empty means
                    every authenticated user reaches it, so infrastructure
                    surfaces should name a role explicitly: signing in is not
                    the same as being allowed in. Roles must already exist in
                    the organisation and match by exact name.
                  '';
                };

                ssoUsers = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [];
                  example = ["zekurio@example.com"];
                  description = "Restrict the resource to these individual users, by email.";
                };

                settings = lib.mkOption {
                  type = lib.types.attrs;
                  default = {};
                  description = ''
                    Extra blueprint keys merged into this resource, for
                    upstream features without a dedicated option here (rules,
                    headers, host-header, healthchecks, ...).
                  '';
                };
              };
            }
          )
        );
      };
    };

    config = lib.mkIf cfg.enable {
      services.newt = {
        enable = true;
        settings = {
          endpoint = cfg.endpoint;
          log-level = "INFO";
        };

        # Targets omit `site`, so Newt assigns them to its own site.
        blueprint.public-resources =
          lib.mapAttrs (
            _: resource:
              {
                name = resource.displayName;
                mode = "http";
                full-domain = resource.domain;
                auth =
                  {sso-enabled = resource.sso;}
                  // lib.optionalAttrs (resource.ssoRoles != []) {sso-roles = resource.ssoRoles;}
                  // lib.optionalAttrs (resource.ssoUsers != []) {sso-users = resource.ssoUsers;};
                targets = [
                  (splitTarget resource.target // {method = "http";})
                ];
              }
              // resource.settings
          )
          cfg.resources;

        # NEWT_ID and NEWT_SECRET come from the site created in Pangolin; the
        # upstream module reads them as environment variables, which also keeps
        # them out of the Nix store.
        environmentFile = config.sops.secrets.newt_env.path;
      };

      # Read by systemd as root before the unit drops to its DynamicUser.
      sops.secrets.newt_env = {
        mode = "0400";
      };
    };
  };
}
