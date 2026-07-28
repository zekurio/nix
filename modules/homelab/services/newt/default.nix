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

    # Deliberately TCP rather than HTTP: every resource here has a single
    # target, so an unhealthy verdict takes the service out of routing with
    # nothing to fail over to. Most of these answer 302 (redirect to Pocket ID)
    # or 307 at /, which an HTTP probe expecting 2xx would read as down.
    healthcheckFor = {
      hostname,
      port,
    }:
      lib.optionalAttrs cfg.healthcheck.enable {
        healthcheck = {
          enabled = true;
          mode = "tcp";
          inherit hostname port;
          interval = cfg.healthcheck.interval;
          unhealthy-interval = cfg.healthcheck.unhealthyInterval;
          timeout = cfg.healthcheck.timeout;
        };
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

      healthcheck = {
        enable =
          lib.mkEnableOption ''
            TCP health checks on every published target
          ''
          // {default = true;};

        interval = lib.mkOption {
          type = lib.types.int;
          default = 30;
          description = "Seconds between probes while a target is healthy.";
        };

        unhealthyInterval = lib.mkOption {
          type = lib.types.int;
          default = 30;
          description = "Seconds between probes while a target is unhealthy.";
        };

        timeout = lib.mkOption {
          type = lib.types.int;
          default = 5;
          description = "Seconds a probe may take before counting as failed.";
        };
      };

      localOnlyDomains = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["internal.zekurio.me"];
        description = ''
          Caddy virtual hosts deliberately not published through the edge, and
          therefore reachable only over the local network.

          checks.edge-coverage fails when a virtual host has no edge route, so
          a domain that is meant to stay local has to say so here. That keeps
          the difference between "local on purpose" and "forgotten" visible in
          the repo rather than discovered when the router ports close.
        '';
      };

      caddyDomains = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["arr.schnitzelflix.xyz"];
        description = ''
          Domains published through the edge as a whole, with Caddy on this host
          left in charge of routing and authentication.

          Pangolin maps a domain to a target and cannot route paths to
          different backends, so domains that Caddy splits by path (or that mix
          public and gated paths) are handed to Caddy intact instead. The
          resource carries no Pangolin SSO: forward auth, the bypass token for
          API clients and per-path rules all keep working exactly as they do on
          the local path.

          Several service modules may name the same domain; duplicates collapse.
        '';
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
                  (
                    splitTarget resource.target
                    // {method = "http";}
                    // healthcheckFor (splitTarget resource.target)
                  )
                ];
              }
              // resource.settings
          )
          cfg.resources
          // lib.listToAttrs (map (domain: {
              name = lib.replaceStrings ["."] ["-"] domain;
              value = {
                name = domain;
                mode = "http";
                full-domain = domain;
                auth.sso-enabled = false;
                # Caddy selects the virtual host by SNI and Host, so both must
                # carry the public name rather than the loopback target.
                host-header = domain;
                tls-server-name = domain;
                targets = [
                  ({
                      hostname = "127.0.0.1";
                      port = 443;
                      method = "https";
                    }
                    // healthcheckFor {
                      hostname = "127.0.0.1";
                      port = 443;
                    })
                ];
              };
            })
            (lib.unique cfg.caddyDomains));

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
