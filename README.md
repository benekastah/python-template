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
  oldest and newest Python supported, a coverage report in the job's summary (a check once
  `fail_under` is set), per-job time limits, a docs-only skip, and one `CI passed` job for a
  ruleset to require.
- **Dependabot** for the locked packages and the actions, weekly, each a week after its
  release.
- **Agent instructions** in two files, which `CLAUDE.md` imports. `AGENTS.md` is the template's,
  shared by every project and kept current by updates: what a change needs (one kind per PR,
  its tests and docs), the tooling, the checks, keeping tests fast, CI's time limits, the
  rules for Linux, macOS and Windows, and how PRs are reviewed. `PROJECT_AGENTS.md` is the
  project's own, a starting point to grow with it: the shape of the code and the project's
  rules, which win where the two disagree.
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

Copier merges them with the project's own changes, marking conflicts as git does. Three files
are starting points, the project's own from the start, and an update never changes them once
written (though it writes one again if it's gone):
`PROJECT_AGENTS.md`, `README.md` and `.github/workflows/check.yml`, since each project's CI
grows its own way. `dev.py`, `AGENTS.md` and `CLAUDE.md` stay the template's: a project adds
commands and install steps in its own `dev_project.py` (see `dev.py`'s docstring), and its own
rules for agents in `PROJECT_AGENTS.md`.

The samples a project rewrites are its own too: an update never changes
`src/<package_name>/cli.py`, `src/<package_name>/__init__.py` or `tests/test_cli.py`, nor
writes one again once deleted.

Everything else an update merges. In `pyproject.toml`, a project's dev dependencies go in
`dev` (`uv add --dev`), apart from the template's in `template-dev`, and its additions to
Ruff's `extend-select` and basedpyright's `include` go below their `# The project's own below:`
line: an addition next to one of the template's lines conflicts when the template changes
that line, e.g. to raise a version. A project made before `template-dev` existed that added to
`dev` conflicts once on it: keep the template's lines, and move its own items into `dev`.

To bring an existing project under the template, move its `AGENTS.md` to `PROJECT_AGENTS.md`
(as in step 1 below), run `copier copy` into its clone, keep what's the project's own in each
conflict, and commit the result with the answers file.

### Moving a project's rules to PROJECT_AGENTS.md

A project made before `AGENTS.md` was the template's has all its rules in `AGENTS.md`. An
update replays the project deleting it, so the template's never arrives on its own. Move to the
new layout once, before that update:

1. `git mv AGENTS.md PROJECT_AGENTS.md`, and remove from it what the template's
   [`AGENTS.md`](template/AGENTS.md) says, keeping the shape of the code, the project's own
   rules, and where it differs from the template's. In the project's README (which an update
   never changes) and its other docs, point to `PROJECT_AGENTS.md` where they mean the
   project's rules, and say `AGENTS.md` is the template's, as a new project's README does.
   Commit.
2. `uvx copier update --defaults`. It keeps `PROJECT_AGENTS.md`, and `CLAUDE.md` now imports
   both files.
3. Render the template's `AGENTS.md` alone, at the commit and from the source the update
   recorded, and commit it with the update. Later updates keep it current.

   ```sh
   tmp=$(mktemp -d)
   uvx copier copy --defaults --data-file .copier-answers.yml \
       --vcs-ref "$(sed -n 's/^_commit: //p' .copier-answers.yml)" -x '*' -x '!AGENTS.md' \
       "$(sed -n 's/^_src_path: //p' .copier-answers.yml)" "$tmp"
   cp "$tmp/AGENTS.md" AGENTS.md
   ```

## Working on the template

`template/` is what Copier renders; files ending in `.jinja` are filled in with the
answers, the rest are copied as they are. The questions are in `copier.yml`. CI
(`.github/workflows/template.yml`) makes a project from the template and runs its
`dev.py check` on Linux, macOS and Windows, and lints its workflows with
[actionlint](https://github.com/rhysd/actionlint). Its `update` job updates a project to a
later template commit, checking that the update merges without conflicts, keeps `AGENTS.md`
current, and leaves the samples and `PROJECT_AGENTS.md` alone. To try a change by hand:

```sh
uvx copier copy --defaults --vcs-ref HEAD -d project_name=sample-tool \
    -d "description=A sample tool." -d "author_name=Your Name" -d author_email=you@example.com \
    . /tmp/sample-tool
cd /tmp/sample-tool && git init && python3 dev.py check
```

`--vcs-ref HEAD` renders the last commit; Copier ignores uncommitted changes.

What `_exclude` in `copier.yml` lists, an update leaves alone: a change to those files reaches
new projects only, so keep it to samples a project rewrites, and put what existing projects
need elsewhere.

Never change `pyproject.toml.jinja`'s `dev = [...]` line or its `# The project's own below:`
lines: projects add to and below them, so a change conflicts in each one.
