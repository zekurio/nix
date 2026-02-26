final: prev: {
  navidrome = prev.navidrome.overrideAttrs (old: {
    env =
      (old.env or {})
      // {
        CGO_CFLAGS_ALLOW = "--define-prefix";
      };
  });
}
