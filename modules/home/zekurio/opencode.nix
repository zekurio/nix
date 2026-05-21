{
  inputs,
  pkgs,
  ...
}: let
  opencode = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
  allowAllPermissions = {
    "*" = "allow";
  };
in {
  home.packages = [opencode];

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
    agent = {
      build.model = "openai/gpt-5.5-fast";
      build.permission = allowAllPermissions;
      plan.model = "openai/gpt-5.5";
      plan.permission = allowAllPermissions;

      git = {
        description = "Runs focused git workflows such as branch creation, commits, pushes, and pull requests.";
        mode = "primary";
        model = "openai/gpt-5.4-mini";
        permission = allowAllPermissions;
        prompt = "You are a focused git workflow agent. Before committing or opening PRs, inspect git status, staged and unstaged diffs, and recent history. Stage only intended repository changes, never rewrite history unless explicitly requested, and keep final responses concise with the branch, commit hash when applicable, and PR URL when applicable.";
      };
    };
    command = {
      branch = {
        description = "Create and switch to a new git branch";
        agent = "git";
        template = ''
          Create and switch to a new git branch named "$1".

          Rules:
          - Use git status first.
          - Create and switch to the branch with git switch -c "$1".
          - Keep the final response to one sentence with the current branch.
        '';
      };

      yeet = {
        description = "Commit all changes and push to remote";
        agent = "git";
        template = ''
          Commit all current repository changes and push them to the configured remote.

          Branch argument: $1

          Rules:
          - If Branch argument is non-empty, create and switch to a new branch with git switch -c "$1".
          - If Branch argument is empty, stay on the current branch.
          - Stage all changes with git add -A.
          - Inspect the staged diff and create one appropriate commit message.
          - Commit the staged changes.
          - Push the current HEAD to the configured upstream remote. If there is no upstream, push with --set-upstream origin <current-branch>.
          - Use git status, git diff, git diff --cached, git log --oneline -10, git add, git commit, and git push only unless a command fails and you need one targeted git command to recover.
          - Do not edit files.
          - Keep the final response to one sentence with the branch and pushed commit hash.
        '';
      };

      pr = {
        description = "Commit, push, and open a PR";
        agent = "git";
        template = ''
          Commit all current repository changes, push them to the configured remote, and open a pull request.

          Branch argument: $1

          Rules:
          - If Branch argument is non-empty, create and switch to a new branch with git switch -c "$1".
          - If Branch argument is empty, stay on the current branch.
          - Stage all changes with git add -A.
          - Inspect the staged diff and create one appropriate commit message.
          - Commit the staged changes.
          - Push the current HEAD to the configured upstream remote. If there is no upstream, push with --set-upstream origin <current-branch>.
          - Build the PR title and body from AGENTS.md instructions when present; otherwise use the first matching PR template you find under .github, docs, or the repo root.
          - Use gh pr create to open the PR against the repository default branch.
          - Use git status, git diff, git diff --cached, git log --oneline -10, git add, git commit, git push, file reads/searches for templates, and gh pr create only unless a command fails and you need one targeted command to recover.
          - Do not edit files.
          - Keep the final response to one sentence with the branch, pushed commit hash, and PR URL.
        '';
      };
    };
    plugin = ["opencode-direnv"];
    provider.openai.models = {
      "gpt-5.4-mini".options = {
        reasoningEffort = "medium";
        textVerbosity = "low";
      };
      "gpt-5.5".options = {
        reasoningEffort = "high";
        textVerbosity = "low";
      };
      "gpt-5.5-fast".options = {
        reasoningEffort = "low";
        textVerbosity = "low";
      };
    };
    server = {
      hostname = "0.0.0.0";
      port = 4096;
    };
  };
}
