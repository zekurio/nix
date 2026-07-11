{...}: {
  programs = {
    atuin = {
      enable = true;
      enableFishIntegration = true;
    };

    fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_greeting

        # SSH into a host and land in the shared, always-alive zellij
        # session instead of a bare shell. Detaching (Ctrl+o d) or quitting
        # closes the connection; the session and its tabs keep running on the
        # host for the next login. Skip when already inside a multiplexer.
        # No `exec`: if the attach fails (e.g. corrupt session) we fall back
        # to a usable shell instead of dropping the connection outright.
        if status is-interactive; and set -q SSH_CONNECTION; and not set -q TMUX; and not set -q ZELLIJ; and command -q zellij
            zellij attach -c main; and exit
        end
      '';
      shellAliases = {
        ls = "eza";
        ll = "eza -lah";
        la = "eza -la";
        lt = "eza --tree";
        cat = "bat";
        claude = "claude --dangerously-skip-permissions";
        codex = "codex --dangerously-bypass-approvals-and-sandbox";
      };
      functions.omp.body = ''
        command omp --allow-home $argv
      '';
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

  # Fish colors come from catppuccin/nix, which installs the Frappé theme and
  # selects it with `fish_config theme choose`.
  catppuccin.fish.enable = true;
}
