# python-template

A [Copier](https://copier.readthedocs.io/) template for a Python command-line project that
runs on Linux, macOS and Windows: an empty project with its tooling set up, drawn from what
[git-stack](https://github.com/benekastah/git-stack),
[git-recommit](https://github.com/benekastah/git-recommit) and move-forward share.

## What a project gets

- **uv** for the virtualenv and a lockfile (`uv.lock`), with a pip fallback for a machine
  without uv. Builds with hatchling, from a `src/` layout.
- **`dev.py`**, the same on every system, standard library only: `venv`, `check`, `static`,
  `tests`, `coverage`, `install` (the package's commands on `PATH`, and the git hooks), and
  what the hooks run.
- **Ruff** for formatting and linting, and **basedpyright** in strict mode for types.
- **pytest** with pytest-xdist (one worker per CPU), and coverage.py.
- **Git hooks**: pre-commit formats and lint-fixes the staged Python files, pre-push runs
  every check before a push to `main`.
- **GitHub Actions**: the static checks once, the tests on Linux, macOS and Windows with the
  oldest and newest Python supported, per-job time limits, Defender and Spotlight off on the
  runners, uv's cache, a docs-only skip, and one `CI passed` job for a ruleset to require.
- **Dependabot** for the locked packages and the actions, weekly, each a week after its
  release.
- **AGENTS.md**: rules for changes, tests and checks, working on Linux, macOS and Windows,
  worktrees for working on several things at once, stacked PRs with git stack, and a review
  loop from PR to merge with fresh agents. **PROJECT_AGENTS.md** holds the project's own
  notes (the shape of its code, its own rules), and wins where the two differ. `CLAUDE.md`
  loads both.
- A README, an MIT license, and a CLI with two tests, to fill in.

## Making a project

```sh
uvx copier copy gh:benekastah/python-template my-tool
```

Copier asks for the project's name, package name, description, author, GitHub user, and the
oldest and newest Python to support, then says what to run next: `git init`, then
`python3 dev.py install` and `python3 dev.py check`. Commit everything it made, `uv.lock` and
`.copier-answers.yml` included.

## Updating a project

A project records its answers in `.copier-answers.yml`, so it can take in the template's
later changes:

```sh
uvx copier update --defaults
```

Copier merges them with the project's own changes, marking conflicts as git does. Two files
are the project's alone from the start, and an update never touches them: `PROJECT_AGENTS.md`
and `README.md`. `AGENTS.md` is the template's: an update brings its new rules, so put what's
true of one project in its PROJECT_AGENTS.md, and change the shared rules here.

To bring an existing project under the template, run `copier copy` into its clone, keep
what's the project's own in each conflict, and commit the result with the answers file.

## Working on the template

`template/` is what Copier renders; files ending in `.jinja` are filled in with the
answers, the rest are copied as they are. The questions are in `copier.yml`. CI
(`.github/workflows/template.yml`) makes a project from the template and runs its
`dev.py check` on Linux, macOS and Windows. To try a change by hand:

```sh
uvx copier copy --defaults --vcs-ref HEAD -d project_name=sample-tool \
    -d "description=A sample tool." -d "author_name=Your Name" -d author_email=you@example.com \
    . /tmp/sample-tool
cd /tmp/sample-tool && git init && python3 dev.py check
```

`--vcs-ref HEAD` renders the last commit; Copier ignores uncommitted changes.
