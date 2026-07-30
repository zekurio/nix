{
  flake.modules.homeManager.zekurio = {
    inputs,
    lib,
    pkgs,
    ...
  }: let
    agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
    pi =
      if pkgs.stdenv.hostPlatform.isDarwin
      then
        agents.pi.overrideAttrs (oldAttrs: {
          # Bun mutates its linker-signed executable while embedding the app,
          # leaving macOS to kill it on launch unless it is signed again.
          nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [pkgs.rcodesign];
          postFixup =
            (oldAttrs.postFixup or "")
            + ''
              ${lib.getExe pkgs.rcodesign} sign --code-signature-flags linker-signed $out/libexec/pi/pi
            '';
        })
      else agents.pi;
  in {
    # Every agent here ships a compiled binary with its runtime embedded, so
    # none of them needs a global node or bun on the host.
    home.packages = [
      agents.claude-code
      agents.codex
      agents.opencode
      pi
    ];
  };
}
