{
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
    };

    zoxide = {
      enable = true;
      options = [
        "--cmd"
        "cd"
      ];
    };
  };
}
