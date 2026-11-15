# Working on this project

Notes for agents (and people) changing this repo: the rules and workflows it shares with
other projects made from [python-template](https://github.com/benekastah/python-template).

**Read [PROJECT_AGENTS.md](PROJECT_AGENTS.md) too**: this project's own notes (the shape of
its code, its own rules and decisions). Where the two differ, PROJECT_AGENTS.md wins. The
README is the user documentation, and its Development section says how to set up a clone and
run the checks.

This file comes from the template, and `copier update` replaces it: change it in
python-template, not here. Put what's true of this project alone in PROJECT_AGENTS.md.

## Rules for changes

- **One kind of change per PR.** A refactor, a new feature and a fix are separate PRs. When
  one change needs another first, land that first, on its own, with its own tests, and stack
  the PR on it (see [Stacked PRs with git stack](#stacked-prs-with-git-stack)).
- **Small enough to review well.** A reviewer reads a PR whole, and reads a small one
  better: split a large change into a stack of PRs that each do one step and pass
  `dev.py check` and CI on their own (a model, then what uses it; a refactor, then the
  feature on it).
- **Keep the docs up to date as you code**, in the same commit as the change, not in a docs
  pass afterwards: the README for behavior (commands, options, output, config),
  PROJECT_AGENTS.md for the shape of the code and the project's own rules, and the docstrings and comments on the code you
  touch. Before committing, search the docs and docstrings for the names you renamed, moved
  or removed.
- **Comments say what's so**, not what the code used to do or ideas that were turned down:
  if Foo was removed, don't write "we don't need Foo".
- **Ask before adding a runtime dependency.** Prefer the standard library. When adding any
  dependency, look up its latest version rather than going by memory, and use it.
- **A class's variables come first**: its class variables, then `__init__`, which sets every
  instance variable, then the methods.
- **Use a library rather than a poor version of what it does**, most of all for anything
  security-sensitive (parsing, crypto, quoting for a shell or SQL).

## Tests and checks

- **Work test-first**: write the tests for a change (or a bug) first, run them and see them
  fail for the reason you expect, then make the change and see them pass. If the code has to
  be reshaped first for the tests to run (e.g. to inject what they replace), do only that
  before seeing them fail, so the failure still shows the old behavior.
- **Every change to behavior comes with tests**, in the same commit, and changes the tests
  that cover the old behavior. Tests say what's correct, not what the code happens to do:
  don't add a test that pins down a bug. Make sure each would fail without the change.
- **Tests keep to themselves**: no network, and not the user's real config, home directory
  or other state; use `tmp_path`, and give programs the tests start a config that reaches
  nothing.
- **Keep the tests fast.** Starting a process costs about 24ms on GitHub's Windows runners
  and 4–7ms on macOS, against under 1ms on Linux, and how Python starts it makes no
  difference, so on those systems the number of processes is what makes a suite slow. Call
  the code in the test's process rather than through its command line, except in the few
  tests of the command line itself; build expensive fixtures (e.g. git repositories) once per
  session and copy them for each test; and prefer one long-lived process (e.g.
  `git cat-file --batch`) over one per request.
- **Before committing, run `python3 dev.py check`**: Ruff's formatter and linter, basedpyright
  in strict mode, then the tests. `python3 dev.py coverage` shows what the tests don't run.
  The pre-commit hook formats and lint-fixes staged files; the pre-push hook runs every
  check before a push to `main`.
- **Each CI job has a time limit** (`timeout-minutes` in `.github/workflows/check.yml`),
  about 20% over how long it takes. If a job runs into its limit, speed it up if you can
  (the tests, or the code itself); only if you can't, raise the limit, saying why.

## Linux, macOS and Windows

The project runs on all three, and CI runs the tests on each. Keep it that way, with
every change:

- Use `pathlib.Path` for paths, not strings joined with `/`, and compare them as `Path`s.
  Write paths into TOML or URLs with `as_posix()`.
- Read and write text as UTF-8 (`encoding="utf-8"`, not `text=True`): Windows' default
  encoding is its code page. Don't assume `\n` line endings in files you didn't write, or a
  case-sensitive filesystem (macOS and Windows usually aren't).
- Run programs with their arguments as a list, never through a shell, and don't call Unix
  tools (`sed`, `grep`, ...) from Python.
- Branch on `sys.platform` rather than assuming POSIX (`fcntl`, `os.fork`, signals, modes).
  When a system needs its own way, give it one rather than skipping it there.
- In tests, make a fake command as a Python script with a launcher, not a shell script or a
  symlink, which Windows can't run or usually can't make. A test that can only run on one
  system says why in its `skipif`, and the other systems get a test of their own.
- Dev tooling goes in `dev.py`, not shell scripts.

## Working on several things at once

Each line of work (a feature, a stack of PRs, an experiment) gets its own git worktree, so
several agents or people can work at once without switching branches under each other:

```sh
git worktree add ../<repo>-<topic> -b <branch> origin/main
cd ../<repo>-<topic> && python3 dev.py venv   # each worktree has its own .venv
git worktree remove ../<repo>-<topic>         # when it's merged
```

- **Leave the main checkout on `main`.** An editable install, an editor or another session
  may be running its code; switching its branch changes their code too, mid-run.
- **One owner per branch.** Don't commit or push to a branch another agent is working on.
  Hand it over explicitly, and say what's unpushed and what's in flight.
- **Don't rewrite pushed history** someone else may have built on. Add commits, or start a
  new branch and PR, rather than force-pushing a shared branch.

## Stacked PRs with git stack

When a change needs another that isn't merged yet, stack them with
[git stack](https://github.com/benekastah/git-stack), which keeps each branch rebased on the
one below it and each PR pointed at its base:

```sh
git stack branch add-model      # a branch for PR 1, on main
# ...commit...
git stack branch use-model      # a branch for PR 2, on PR 1
# ...commit...
git stack push --prs            # push both, and open draft PRs, each into the branch it's on
git stack info                  # the stack, each branch's PR, and what needs restacking
git stack restack               # after changing a lower branch: rebase the ones above it
git stack sync                  # after a merge: drop merged PRs, rebase what's left, push
```

## From PR to merge

1. **Branch** in a worktree (stacked if it builds on unmerged work). Commit in small, logical
   steps whose messages say why, not just what. `python3 dev.py check` must pass on the last
   commit: PRs are squash-merged, so that's what reaches `main`.
2. **Open a draft PR** (`git stack push --prs`, or `gh pr create --draft`). An agent's PR
   description, and every comment it posts, says in its first line that an AI agent wrote
   it, since it's posted from a person's account.
3. **Review it with a fresh agent**: a new subagent with no context but the PR, not a fork of
   the session that wrote it, so it judges what the code says rather than what was meant. It
   reads the diff against the PR's base, its commit messages and this file, and changes
   nothing. It looks for, most important first: bugs (inputs or state that give a wrong
   result or a crash); surprises, and what the change makes inconsistent outside itself;
   missing tests, tests that can't fail without the change, or that enshrine wrong behavior;
   missing or untrue docs, docstrings and comments; dead code; readability; security. It
   checks each finding against the code before reporting it, with a severity (bug,
   should-fix, minor), a failure scenario and a fix. It posts one GitHub review of type
   COMMENT, never approving or requesting changes, with its findings numbered, each inline on
   its line where it has one:

   ```sh
   gh pr view N --json headRefOid -q .headRefOid   # the head GitHub has, not a local one
   gh api repos/{owner}/{repo}/pulls/N/reviews --method POST --input "$TMP/review.json"
   # {"commit_id": "<that sha>", "event": "COMMENT", "body": "...",
   #  "comments": [{"path": "src/...", "line": 42, "side": "RIGHT", "body": "1. bug: ..."}]}
   ```

   Keep the JSON in a temporary directory, never the repo, where a commit could pick it up.
4. **Fix, then answer every finding.** The PR's author decides what to fix, fixes it and
   pushes, then answers each finding, none skipped (inline ones in their thread, the body's
   in one PR comment): fixed, with the commit's short hash, or why not (wrong, out of scope,
   or not worth its cost).
5. **Review the fixes the same way**, with another fresh agent, on what changed since the
   reviewed head (`<reviewed sha>..HEAD`), unless all they change is wording. Repeat 4 and 5
   until a review finds no bugs or should-fixes.
6. **Merge when it's ready**: reviews answered, CI green, and the go-ahead from whoever owns
   the repo. Merge in stack order, squashed, then run `git stack sync` to rebase what's
   left.

After a run of merges, or when asked, review the whole code the same way: several fresh
agents at once, each given one part (a module, the tests, the tooling and CI, the docs
against the code, what cuts across) at one commit of `main`, posting their findings on one
issue; then fix them in PRs as above.
