{
  flake.modules.darwin.sachiel = {
    pkgs,
    lib,
    ...
  }: {
    # The deferred `flake.modules.darwin.sachiel` slot nests this one `imports`
    # level below nix-darwin's baseModules, which moves this entry ahead of the
    # darwin default systemPackages instead of after them. The pre-dendritic
    # host module contributed openssh last; mkAfter restores that position so the
    # merged system-path is byte-identical.
    environment.systemPackages = lib.mkAfter (with pkgs; [
      nodejs
      openssh
      python3
      uv
    ]);
  };
}
