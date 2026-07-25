{
  flake.modules.darwin.base = {pkgs, ...}: {
    fonts.packages = [
      pkgs.nerd-fonts.fira-code
    ];
  };
}
