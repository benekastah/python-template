# python-template

A [Copier](https://copier.readthedocs.io/) template for a Python command-line project that
runs on Linux, macOS and Windows: an empty project with its tooling set up, drawn from what
[git-stack](https://github.com/benekastah/git-stack),
[git-recommit](https://github.com/benekastah/git-recommit) and move-forward share.

## What a project gets

- **uv** for the virtualenv and a lockfile (`uv.lock`), with a pip fallback for a machine
  without uv. Builds with hatchling, from a `src/` layout.
- **`dev.py`**, the same on every system, standard library only: `venv`, `check`, `static`,
  `tests`, `coverage`, `man`, `install` (the package's commands on `PATH`, their man pages
  where `man` looks, and the git hooks, never taking a command over from another clone
  unasked, or installing a temporary one), and what the hooks run.
- **A man page for each command**, `man/<command>.1`, made from the README with pandoc
  (a pinned version, which dev.py downloads and checks) by `dev.py man`: NAME from the command and the description,
  then the README's opening and its sections, but not Installing and Development. A
  project's `dev_project.py` can change which sections it leaves out, and give it a
  SYNOPSIS. The pre-commit hook makes them again from the staged README, and the static
  checks fail if one is out of date, in CI too, even when docs alone changed, if the README
  did. `install` links them into `~/.local/share/man/man1`, but not on Windows, which has no
  `man`. A library, with no commands, has none.
- **Ruff** for formatting and linting, and **basedpyright** in strict mode for types.
- **pytest** with pytest-xdist (one worker per CPU), and coverage.py.
- **Git hooks**: pre-commit formats and lint-fixes the staged Python files and makes the man
  pages again, pre-push runs the static checks before every push.
- **GitHub Actions**, on pull requests into `main` and on `main`: the static checks once,
  the tests on Linux, macOS and Windows with the oldest and newest Python supported (on a
  system where they're slow, split over several jobs, as the project's answers say), a
  coverage report in the job's summary (a check once `fail_under` is set), a time limit of at
  most 5 minutes on each job, a docs-only skip, cancelling superseded runs and a pull
  request's run once it merges or closes, and one `CI passed` job for a ruleset to require
  (in rapid development, it lets a pull request through when its macOS or Windows test jobs
  never got a runner, if Linux's passed, and names them in a warning).
  It is the only check a ruleset may require: the others can report as skipped (on a
  docs-only change, or a pull request above a GitHub stack's bottom), which counts as
  passing. The jobs set up uv and Python with a composite action, `.github/actions/setup`.
  `copier update` keeps all that current, while the project's own jobs go in
  `.github/workflows/project.yml`, which `CI passed` waits for too.
- **Dependabot** for the locked packages and the actions, weekly, each a week after its
  release.
- **Agent instructions** in two files, which `CLAUDE.md` imports. `AGENTS.md` is the template's,
  shared by every project and kept current by updates: what a change needs (one kind per PR,
  its tests and docs), the tooling, the checks, keeping tests fast, CI's time limits, the
  rules for Linux, macOS and Windows, and how PRs are reviewed. `PROJECT_AGENTS.md` is the
  project's own, a starting point to grow with it: the shape of the code and the project's
  rules, which win where the two disagree.
- **`docs/issues.md` and `docs/roadmap.md`**, each with a short header: what's wrong with
  what's built, and what's left to build. `AGENTS.md` tells agents to keep them current.
- A README, an MIT license, and a CLI with two tests, to fill in.

## Making a project

```sh
uvx copier copy gh:benekastah/python-template my-tool
```

Copier asks for the project's name, package name, description, author, GitHub user, the
oldest and newest Python to support, and how many CI jobs to split the tests into on each
system (1 to start with), then says what to run next: `git init`, then `python3 dev.py man`,
`python3 dev.py install` and `python3 dev.py check`. Commit everything it made, `uv.lock`,
`man/` and `.copier-answers.yml` included.

## Updating a project

A project records its answers in `.copier-answers.yml`, so it can take in the template's
later changes:

```sh
uvx copier update --defaults
```

Copier merges them with the project's own changes, marking conflicts as git does. It keeps the
project's answers, and gives a question added since its default; `-d NAME=VALUE` changes an
answer. A project whose tests take too long for one CI job on a system splits them over several
there, with `test_shards_linux`, `test_shards_macos` or `test_shards_windows` (each 1 by
default, at most 8), e.g. `uvx copier update --defaults -d test_shards_windows=3`; its
`AGENTS.md` says how to do that without taking in the template's other changes. So does
`rapid_development` (true by default, also for a project made before the question): once others
depend on a release and most changes are fixes, set it to false, so agents split changes into
smaller PRs and `CI passed` fails a pull request whose tests never got a runner too.

Five files are starting points, the project's own from the start, and an update never changes
them once written (though it writes one again if it's gone): `PROJECT_AGENTS.md`, `README.md`,
`docs/issues.md`, `docs/roadmap.md` and `.github/workflows/project.yml`, the project's own CI
jobs. The rest stays the template's, so an update keeps it current:

- `dev.py`: a project adds commands and install steps in its own `dev_project.py` (see
  `dev.py`'s docstring).
- `AGENTS.md` and `CLAUDE.md`: a project adds its own rules for agents in
  `PROJECT_AGENTS.md`.
- `.github/workflows/ci.yml` and the action it sets up jobs with, `.github/actions/setup`:
  the static checks, the tests, coverage, the time limits, cancelling superseded runs, and
  `CI passed`, which waits for `project.yml`'s jobs too (`ci.yml` calls it), so they gate
  merges like the rest. A job in `project.yml` reads what `ci.yml` passes it from one JSON
  input, `context`: `code` (false when docs alone changed, to skip with
  `if: fromJSON(inputs.context).code`), `min_python` and `newest_python`. The template can
  add keys to it without breaking a project. A job there can't `needs` a job in `ci.yml`,
  and gets at most `contents: read`: one needing more (to publish, say) goes in a workflow of
  its own.
- `.github/workflows/cancel.yml`, which cancels a pull request's `ci.yml` run when it merges
  or closes.

`ci.yml` runs on pull requests into `main` and on pushes to it, not on a pull request stacked
on another one: that one is rebased and pushed again once the one below it merges, which
would throw its run away, and runners (macOS ones especially) are scarce. In one of GitHub's
own stacks, such a pull request still starts a run, but its jobs all skip, and the skipped
`CI passed` job is shown by its name's expression as written, since GitHub doesn't evaluate
a skipped job's name: never `CI passed`, so it can't pass a ruleset. So merge such a stack
one pull request at a time, from the bottom, each once its own run has passed: an upper one
never gets `CI passed`, so merging it, and the stack under it, waits forever. It runs once the
pull request targets `main` and is pushed: GitHub's stacks push the pull request rebased onto
`main` when the one below merges, and git stack pushes once it has retargeted it. A retarget
alone starts no run: GitHub's own, when the branch below is deleted outside a GitHub stack,
one by hand, or git stack's when it has nothing new to push. Nor does editing a pull request,
since a newer run of `ci.yml` on the same commit was seen to hide `CI passed` from the
ruleset. Then push again, or close and reopen the pull request (re-running an earlier run
won't do: it keeps the old base). Until then, run
`dev.py static` and the tests near the change locally.

Copier merges the template's changes to these with the project's, so a Dependabot bump to an
action in them can conflict with the template's: keep the newer version.

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
(as in step 1 of "Moving a project's rules to PROJECT_AGENTS.md" below), run `copier copy`
into its clone, keep what's the project's own in each conflict, move its own CI jobs into
`project.yml` (as in "Moving to `ci.yml` from `check.yml`" below), and commit the result with
the answers file.

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
   uvx copier copy -q --defaults --data-file .copier-answers.yml \
       --vcs-ref "$(sed -n "s/^_commit: //p" .copier-answers.yml | tr -d "'")" \
       -x '*' -x '!AGENTS.md' \
       "$(sed -n "s/^_src_path: //p" .copier-answers.yml | tr -d "'")" "$tmp"
   cp "$tmp/AGENTS.md" AGENTS.md
   ```

### Moving to `ci.yml` from `check.yml`

A project made before the template owned its CI has a `.github/workflows/check.yml` of its
own. The update that brings in `ci.yml` deletes `check.yml`, even if the project changed it,
without marking a conflict. Leave it deleted (with both, every push would run the full CI
twice), but before committing the update:

1. Look for what the project changed in it: `git log -p -- .github/workflows/check.yml`.
2. Move the project's own jobs into `project.yml`, in place of its placeholder `none` job,
   setting up with `./.github/actions/setup` after the checkout, and taking the Pythons
   from `fromJSON(inputs.context)` (see `project.yml`). Where `CI passed` needed them, it
   now waits for all of `project.yml`.
3. Make any changes the project made to the template's jobs (a raised time limit, say) in
   `ci.yml`.
4. Replace `check.yml` in what the project's README and `PROJECT_AGENTS.md` say about CI.
5. Commit, with `ci.yml`, `cancel.yml`, `project.yml` and `.github/actions/`. A ruleset
   requiring `CI passed` needs no change.

## Working on the template

`template/` is what Copier renders; files ending in `.jinja` are filled in with the answers,
the rest are copied as they are. The questions are in `copier.yml`. CI
(`.github/workflows/template.yml`) makes a project from the template and runs its
`dev.py check` with the oldest and newest Python, and checks there that
`dev.py tests --shard I/N` runs each test in exactly one shard. That is on Linux, and on macOS
and Windows too when a pull request changes `template/dev.py`, `template/git_hooks/`,
`template/pyproject.toml.jinja`, `template/.gitattributes`, `template/.github/actions/` or `template.yml` (code that differs
per system), and on every push to `main`. Like a project's `ci.yml`, it runs only for a
pull request into `main`: a stacked one gets CI once it targets `main`, so run the sample's
checks by hand (below) until then. It lints its workflows, and
those of a project with shards, with [actionlint](https://github.com/rhysd/actionlint). Its
`update` job updates a project to a later template commit, changing an answer as it does,
checking that the update merges without conflicts, keeps `AGENTS.md` and `ci.yml` current, and
leaves the samples, `PROJECT_AGENTS.md`, `docs/` and `project.yml` alone. A pull request that
changes only Markdown outside `template/` skips all of that. To try a change by hand:

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

Never rename or remove a key of the `context` that `ci.yml` passes `project.yml`, or change
its type; only add keys. Nothing checks the keys a project's job reads: a missing one reads as
null, so a job with `if: fromJSON(inputs.context).code` would skip without a word, and
`CI passed` accepts a skipped `project.yml`.
