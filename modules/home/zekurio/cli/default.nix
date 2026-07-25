{
  flake.modules.homeManager.zekurio = {inputs, ...}: {
    imports = [
      inputs.catppuccin.homeModules.catppuccin
    ];

    home.shellAliases = {
      claude = "claude --dangerously-skip-permissions";
      codex = "codex --dangerously-bypass-approvals-and-sandbox";
    };

    programs.btop.enable = true;

    # autoEnable is off so only the ports enabled next to each program are
    # themed; flavor and accent cascade to every port.
    catppuccin =
      {
        enable = true;
        autoEnable = false;
      }
      // import ../../../_palette.nix;
  };
}
