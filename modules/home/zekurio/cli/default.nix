{
  flake.modules.homeManager.zekurio = {inputs, ...}: {
    imports = [
      inputs.catppuccin.homeModules.catppuccin
    ];

    home.shellAliases = {
      ls = "eza";
      ll = "eza -lah";
      la = "eza -la";
      lt = "eza --tree";
      cat = "bat";
      claude = "claude --dangerously-skip-permissions";
      codex = "codex --dangerously-bypass-approvals-and-sandbox";
    };

    programs = {
      bat.enable = true;
      btop.enable = true;
    };

    # autoEnable is off so only the ports enabled next to each program are
    # themed; flavor and accent cascade to every port.
    catppuccin =
      {
        enable = true;
        autoEnable = false;
        bat.enable = true;
      }
      // import ../../../_palette.nix;
  };
}
