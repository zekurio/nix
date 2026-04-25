{
  lib,
  config,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.modules.dev;
  codexPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  codexWithSandbox = pkgs.runCommand "codex-with-sandbox" {} ''
    mkdir -p $out/bin
    ln -s ${codexPackage}/bin/codex $out/bin/codex
    ln -s ${codexPackage}/bin/codex $out/bin/codex-linux-sandbox
  '';
in {
  imports = [
    ./git.nix
  ];

  options.modules.dev.enable = lib.mkEnableOption "development tools and git config";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
      codexWithSandbox
      pkgs.codex-acp
      pkgs.nil
      pkgs.nixd
      pkgs.uv
    ];
  };
}
