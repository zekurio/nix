{
  flake.modules.homeManager.zekurio = {
    programs = {
      fish = {
        enable = true;
        interactiveShellInit = ''
          set fish_greeting
        '';
        shellAliases = {
          ls = "eza";
          ll = "eza -lah";
          la = "eza -la";
          lt = "eza --tree";
          cat = "bat";
        };
      };

      carapace = {
        enable = true;
        enableFishIntegration = true;
      };

      zoxide = {
        enable = true;
        enableFishIntegration = true;
        options = [
          "--cmd"
          "cd"
        ];
      };
    };
  };
}
