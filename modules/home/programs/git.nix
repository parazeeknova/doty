{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaGit = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova.programs.git = {
      enable = true;
      signing = {
        signByDefault = true;
        key = "/home/parazeeknova/.ssh/github_signing_key.pub";
      };
      settings = {
        user = {
          name = "Harsh Sahu";
          email = "yesh8harsh+github@gmail.com";
        };
        core = {
          compression = 9;
          whitespace = "error";
          preloadindex = true;
        };
        advice = {
          addEmptyPathSpec = false;
          pushNonFastForward = false;
          statusHints = false;
        };
        init.defaultBranch = "dev";
        status = {
          branch = true;
          showStash = true;
          showUntrackedFiles = "all";
        };
        diff = {
          context = 3;
          renames = "copies";
          interHunkContext = 10;
        };
        pager = {
          diff = "diff-so-fancy | $PAGER";
          branch = false;
          tag = false;
        };
        "diff-so-fancy".markEmptyLines = false;
        interactive = {
          diffFilter = "diff-so-fancy --patch";
          singleKey = true;
        };
        push = {
          autoSetupRemote = true;
          default = "current";
          followTags = true;
        };
        pull = {
          default = "current";
          rebase = true;
        };
        rebase = {
          autoStash = true;
          missingCommitsCheck = "warn";
        };
        log.abbrevCommit = true;
        branch.sort = "-committerdate";
        tag = {
          sort = "-taggerdate";
          gpgsign = true;
          forceSignAnnotated = true;
        };
        commit.gpgsign = true;
        "gpg \"ssh\"" = {
          program = "ssh-keygen";
          allowedSignersFile = "~/.ssh/allowed_signers";
        };
        gpg = {
          format = "ssh";
          program = "gpg";
        };
        alias = {
          sw = "switch";
          co = "checkout";
          br = "branch";
          ci = "commit";
          st = "status";
          lg = "log --oneline --graph --decorate -20";
        };
      };
      ignores = [
        "*.swp"
        "*.swo"
        "*~"
        ".DS_Store"
        "Thumbs.db"
        "__pycache__/"
        "*.pyc"
        ".env"
        "node_modules/"
        ".direnv/"
        "result"
      ];
    };
  };
}
