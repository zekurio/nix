{
  inputs,
  pkgs,
  ...
}: let
  opencode = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
in {
  home.packages = [opencode];

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
    command = {
      branch = {
        description = "Create and switch to a new git branch";
        template = ''
          !`git switch -c "$1"`
        '';
      };

      yeet = {
        description = "Commit all changes and push to remote";
        model = "openai/gpt-5.4-mini";
        template = ''
          Commit all current repository changes and push them to the configured remote.

          Branch argument: $1

          Rules:
          - If Branch argument is non-empty, first switch to that branch with git switch "$1".
          - Stage all changes with git add -A.
          - Inspect the staged diff and create one appropriate commit message.
          - Commit the staged changes.
          - Push the current HEAD to the configured upstream remote. If there is no upstream, push with --set-upstream origin <current-branch>.
          - Use git status, git diff --cached, git log --oneline -10, git add, git commit, and git push only unless a command fails and you need one targeted git command to recover.
          - Do not edit files.
          - Keep the final response to one sentence with the branch and pushed commit hash.
        '';
      };

      pr = {
        description = "Commit, push, and open a PR";
        model = "openai/gpt-5.4-mini";
        template = ''
          Commit all current repository changes, push them to the configured remote, and open a pull request.

          Branch argument: $1

          Rules:
          - If Branch argument is non-empty, first switch to that branch with git switch "$1".
          - Stage all changes with git add -A.
          - Inspect the staged diff and create one appropriate commit message.
          - Commit the staged changes.
          - Push the current HEAD to the configured upstream remote. If there is no upstream, push with --set-upstream origin <current-branch>.
          - Build the PR title and body from AGENTS.md instructions when present; otherwise use the first matching PR template you find under .github, docs, or the repo root.
          - Use gh pr create to open the PR against the repository default branch.
          - Use git status, git diff --cached, git log --oneline -10, git add, git commit, git push, file reads/searches for templates, and gh pr create only unless a command fails and you need one targeted command to recover.
          - Do not edit files.
          - Keep the final response to one sentence with the branch, pushed commit hash, and PR URL.
        '';
      };
    };
    plugin = ["opencode-direnv"];
    provider.openai.models."gpt-5.4-mini".options = {
      reasoningEffort = "high";
      textVerbosity = "low";
    };
    server = {
      hostname = "0.0.0.0";
      port = 4096;
    };
  };

  systemd.user.services.opencode-web = {
    Unit = {
      Description = "OpenCode web server";
      After = ["network-online.target"];
      Wants = ["network-online.target"];
    };

    Service = {
      ExecStart = "${opencode}/bin/opencode web --hostname 0.0.0.0 --port 4096";
      Restart = "on-failure";
      RestartSec = 5;
      WorkingDirectory = "%h";
    };

    Install.WantedBy = ["default.target"];
  };
}
