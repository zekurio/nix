{...}: {
  flake.modules.nixos.lilith = {
    config,
    lib,
    pkgs,
    ...
  }: let
    username = "zekurio";
    uid = toString config.users.users.${username}.uid;
    cacheDir = "/var/lib/dms-greeter/users/${username}";
  in {
    # AccountsService deliberately keeps the user-selected icon in the user's
    # private home. DMS 1.5.3 rejects even `dms greeter sync --profile` when the
    # native NixOS module is active, so mirror only the current icon into DMS's
    # readable per-user cache instead of declaring account metadata in Nix.
    systemd.services.dms-greeter-avatar = {
      description = "Sync the AccountsService avatar to the DMS greeter";
      wantedBy = ["greetd.service"];
      before = ["greetd.service"];

      serviceConfig = {
        Type = "oneshot";
        PrivateTmp = true;
      };

      script = ''
        cache=${lib.escapeShellArg cacheDir}
        ${pkgs.coreutils}/bin/install -d -o dms-greeter -g dms-greeter -m 0750 \
          /var/lib/dms-greeter/users "$cache"

        # Remove the old mirror first so clearing the AccountsService avatar is
        # reflected by the greeter too.
        ${pkgs.coreutils}/bin/rm -f \
          "$cache/profile.jpg" \
          "$cache/profile.jpeg" \
          "$cache/profile.png" \
          "$cache/profile.webp"

        property="$(${pkgs.systemd}/bin/busctl --system --json=short get-property \
          org.freedesktop.Accounts \
          /org/freedesktop/Accounts/User${uid} \
          org.freedesktop.Accounts.User \
          IconFile || true)"
        avatar="$(${pkgs.jq}/bin/jq -r '.data // empty' <<< "$property")"

        if [[ -n "$avatar" && -f "$avatar" ]]; then
          tmp="$cache/.profile.jpg.tmp"
          ${pkgs.coreutils}/bin/install -o dms-greeter -g dms-greeter -m 0644 \
            "$avatar" "$tmp"
          ${pkgs.coreutils}/bin/mv -f "$tmp" "$cache/profile.jpg"
        fi
      '';
    };

    # AccountsService rewrites this file whenever the user changes their
    # avatar, so keep the greeter mirror current without requiring a rebuild.
    systemd.paths.dms-greeter-avatar = {
      description = "Watch for AccountsService avatar changes";
      wantedBy = ["multi-user.target"];
      pathConfig.PathChanged = "/var/lib/AccountsService/users/${username}";
    };
  };
}
