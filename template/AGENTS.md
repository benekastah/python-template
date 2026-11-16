# Working on this project

Read `PROJECT_AGENTS.md` too: it has this project's own shape of the code, rules and
decisions. Where the two disagree, `PROJECT_AGENTS.md` wins.

This file holds the rules every project made from
[python-template](https://github.com/benekastah/python-template) shares. It's the template's:
`uvx copier update --defaults` keeps it current, so change it in the template, and put what's
this project's own in `PROJECT_AGENTS.md`. The README is the user documentation; its
Development section says how to set up a clone and run the checks.

## Making a change

- **One kind of change per PR**: a refactor, a feature and a fix are separate PRs, each small
  enough to review whole. When one needs another first, that one lands first, on its own,
  with its own tests.
- **Every change to behavior comes with tests**, in the same commit, that would fail without
  it, and changes the tests that cover the old behavior. Tests say what's correct, not what
  the code happens to do: don't add a test that pins down a bug.
- **Docs change with the code**, in the same commit: the README for behavior,
  `PROJECT_AGENTS.md` for the shape of the code and its rules, and the docstrings and
  comments on the code you touch. Before committing, search the docs for the names you
  renamed, moved or removed.
- **Commit messages say why**, not just what.
- **No new runtime dependency** without a good reason: prefer the standard library.

## Tooling

- `dev.py` sets up a clone and runs the checks, the same on every system (on Windows, run
  it with `py`); `python3 dev.py` lists its commands. It's the template's: this project's
  own commands and install steps go in `dev_project.py` (see `dev.py`'s docstring).
- Dev tooling goes in `dev.py` or `dev_project.py`, not shell scripts; the git hooks are
  the only ones. The pre-commit hook formats and lint-fixes staged files; the pre-push hook
  runs every check before a push to `main`.
- `pyproject.toml` is partly the template's. Add dev dependencies to `dev` with
  `uv add --dev`, never to `template-dev`, and add to Ruff's `extend-select` and
  basedpyright's `include` below their `# The project's own below:` line, which stays as it
  is, so the template's changes merge without conflicts.

## Tests and checks

- **Before committing, run `python3 dev.py check`**: Ruff's formatter and linter, basedpyright
  in strict mode, then the tests. `python3 dev.py coverage` shows what the tests don't run.
- **PRs are squash-merged**, so the checks must pass on a PR's last commit, and CI must pass
  on it too: main's ruleset requires the "CI passed" check.
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
- **Each CI job has a time limit** (`timeout-minutes`), about 20% over how long it takes in
  finished runs, rounded up to a whole minute. If a job runs into its limit, speed it up if
  you can (the tests, or the code itself); only if you can't, raise the limit, saying why in
  the commit.

## Linux, macOS and Windows

The project runs on all three, and CI runs the tests on each. Keep it that way, with every
change:

- Use `pathlib.Path` for paths, not strings joined with `/`, and compare them as `Path`s.
  Write paths into TOML or URLs with `as_posix()`.
- Read and write text as UTF-8 (`encoding="utf-8"`, not `text=True`): Windows' default
  encoding is its code page. Don't assume `\n` line endings in files you didn't write, or a
  case-sensitive filesystem (macOS and Windows usually aren't).
- Run programs with their arguments as a list, never through a shell, and don't call Unix
  tools (`sed`, `grep`, ...) from Python. The project itself mustn't need a shell.
- Branch on `sys.platform` rather than assuming POSIX (`fcntl`, `os.fork`, signals, modes).
  When a system needs its own way, give it one rather than skipping it there.
- In tests, make a fake command as a Python script with a launcher, not a shell script or a
  symlink, which Windows can't run or usually can't make. A test that can only run on one
  system says why in its `skipif`, and the other systems get a test of their own.

## Reviewing

Every PR is reviewed before it merges, drafts included, by a fresh agent with no context but
the PR (not a fork of the session that wrote it), so it judges what the code says rather than
what was meant.

- **The reviewer** reads the diff against the PR's base, its commit messages, this file and
  `PROJECT_AGENTS.md`, and changes nothing. It looks for, most important first: bugs;
  surprises, and what the change makes inconsistent outside itself; tests that are missing,
  couldn't fail without the change, or pin down a wrong behavior; docs and comments that are
  missing or untrue; dead code; readability; security. It checks each finding against the
  code, and gives it a severity (bug, should-fix, minor), a failure scenario and a fix.
- **It posts one GitHub review of type COMMENT** (never approving or requesting changes),
  saying in its first line that an AI agent wrote it, its findings numbered, each inline on
  its line where it has one. The JSON goes in a temporary directory, not the repo:

  ```sh
  gh pr view N --json headRefOid -q .headRefOid   # the head GitHub has, not a local one
  gh api repos/{owner}/{repo}/pulls/N/reviews --method POST --input "$TMP/review.json"
  # {"commit_id": "<that sha>", "event": "COMMENT", "body": "...",
  #  "comments": [{"path": "src/...", "line": 42, "side": "RIGHT", "body": "1. bug: ..."}]}
  ```
- **The PR's author** fixes what it decides to, pushes, then answers every finding (inline
  ones in their thread, the body's in one PR comment): fixed, with the commit's short hash,
  or why not (wrong, out of scope, or not worth its cost).
- **Fixes are reviewed too**, the same way, on `<reviewed sha>..HEAD`, unless all they
  change is wording.

After a run of merges, several fresh agents review the whole code at once, each one part (a
module, the tests, the tooling and CI, the docs against the code) at one commit of `main`,
posting their findings on one issue; the fixes are PRs as above.
