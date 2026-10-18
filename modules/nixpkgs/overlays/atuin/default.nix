let
  # atuin 18.23.0's e2e_capture and e2e_pty suites drive interactive shells
  # through a pty and time out inside the Darwin build sandbox. Too many tests
  # fail to skip individually, so the check phase goes. The guard keeps this
  # from outliving the release; drop the file once a newer atuin builds on
  # sachiel.
  overlay = _final: previous: {
    atuin = previous.atuin.overrideAttrs (
      old:
        previous.lib.optionalAttrs (old.version == "18.23.0") {
          doCheck = false;
        }
    );
  };
in {
  flake.modules.darwin.base.nixpkgs.overlays = [overlay];
}
