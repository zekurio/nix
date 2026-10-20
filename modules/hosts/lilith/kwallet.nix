{
  flake.modules.nixos.lilith = {
    lib,
    pkgs,
    ...
  }: {
    # pam_kwallet starts ksecretd at login, and this unit then pipes the user
    # manager's environment into it. ksecretd reads that stream with fgets into
    # a 1000-byte buffer, so NixOS's multi-kilobyte XDG_DATA_DIRS gets cut
    # mid-path and loses share/union. The Union widget style then finds no
    # "breeze" style, dereferences it anyway and segfaults, so the wallet never
    # unlocks. Dropping lines that do not fit leaves ksecretd with the PAM
    # values, which already include the system profile. The unit comes through
    # pathsToLink, so it has to be extended as a drop-in.
    systemd.user.services.plasma-kwallet-pam = {
      overrideStrategy = "asDropin";
      # Forward the session PATH instead of the minimal one NixOS adds to units.
      enableDefaultPath = false;
      serviceConfig.ExecStart = [
        ""
        (pkgs.writeShellScript "pam-kwallet-init" ''
          if [ -n "$PAM_KWALLET5_LOGIN" ]; then
            ${lib.getExe' pkgs.coreutils "env"} \
              | ${lib.getExe pkgs.gawk} 'length($0) < 999' \
              | ${lib.getExe pkgs.socat} STDIN "UNIX-CONNECT:$PAM_KWALLET5_LOGIN"
          fi
        '')
      ];
    };
  };
}
