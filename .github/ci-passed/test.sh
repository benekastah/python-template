#!/usr/bin/env bash
# Tests the verdict of the projects' CI passed job (its "Fail unless every check passed" step)
# against the jobs API's real answers, from runs whose macOS job never got a runner, and
# variants of them. The step runs as GitHub runs it, with a fake `gh` that answers from those
# files. In them, the CI passed job is still running, as it is when the step runs.
# Usage: test.sh RAPID_CI_YML STRICT_CI_YML, the ci.yml of a project rendered with
# rapid_development true, then false. Needs bash, jq and yq (mikefarah's, as on GitHub's
# runners).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# gh api [--paginate] PATH [--jq FILTER]: the jobs from $JOBS, every job's annotations from
# $ANNOTATIONS.
mkdir "$tmp/bin"
cat > "$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
filter=.
while [ $# -gt 0 ]; do
  case $1 in
    api | --paginate) ;;
    --jq) filter=$2; shift ;;
    *) path=$1 ;;
  esac
  shift
done
case $path in
  */jobs) jq -r "$filter" "$JOBS" ;;
  */annotations) jq -r "$filter" "$ANNOTATIONS" ;;
  *) echo "fake gh: unexpected $path" >&2; exit 2 ;;
esac
EOF
chmod +x "$tmp/bin/gh"

step() {
  yq '.jobs.passed.steps[] | select(.name == "Fail unless every check passed") | .run' "$1"
}
step "$1" > "$tmp/rapid.sh"
step "$2" > "$tmp/strict.sh"

recommit=$here/git-recommit-44114087836-1.json  # macOS never started
stack=$here/git-stack-44114114268-1.json  # macOS 1/2 never started, 2/2 passed
not_acquired=$here/not-acquired-annotations.json
echo '[]' > "$tmp/none.json"
echo '[{"annotation_level": "failure", "message": "Canceling since a higher priority waiting request for ci-107 exists"}]' \
  > "$tmp/superseded.json"

# Each job of $1 that matches the jq condition $2 changed by the jq update $3.
variant() {
  jq "(.jobs[] | select($2)) |= ($3)" "$1" > "$tmp/variant.json"
  echo "$tmp/variant.json"
}
never_started='.conclusion = "cancelled" | .runner_name = "" | .steps = []'
got_runner='.runner_name = "GitHub Actions 1"'
started_step='.steps = [{"name": "Set up job", "started_at": "2026-11-17T15:25:15Z"}]'

failures=0
# check WANT SCRIPT JOBS ANNOTATIONS [NAME=VALUE...]: runs the step as GitHub would (bash -e),
# with the needs' results of a run whose tests alone didn't pass (as the API reports a run with
# a job that never got a runner), and checks its exit status: pass or fail.
check() {
  local want=$1 script=$2 got=pass
  : > "$tmp/summary"
  env PATH="$tmp/bin:$PATH" JOBS="$3" ANNOTATIONS="$4" GITHUB_STEP_SUMMARY="$tmp/summary" \
    GITHUB_REPOSITORY=o/r GITHUB_RUN_ID=1 GITHUB_RUN_ATTEMPT=1 GH_TOKEN=x \
    CHANGES=success CODE=true STATIC=success TESTS=abandoned COVERAGE=success PROJECT=success \
    EVENT=pull_request "${@:5}" bash -e "$tmp/$script.sh" > "$tmp/out" 2>&1 || got=fail
  if [ "$got" != "$want" ]; then
    echo "FAIL: $script ${*:3}: wanted $want, got $got"
    cat "$tmp/out"
    failures=$((failures + 1))
  fi
}
# shows TEXT FILE: FILE has the line TEXT.
shows() {
  if ! grep -qxF -- "$1" "$2"; then
    echo "FAIL: no line '$1' in:"
    cat "$2"
    failures=$((failures + 1))
  fi
}

# A pull request's macOS job that never got a runner is skipped, and named.
check pass rapid "$recommit" "$not_acquired"
shows '::warning title=Tests skipped::Never started, for want of a runner, so not run: macos-latest, Python 3.15' "$tmp/out"
shows '- macos-latest, Python 3.15' "$tmp/summary"
check pass rapid "$stack" "$not_acquired"
shows '- macos-latest, Python 3.15 (1/2)' "$tmp/summary"
# Windows too, alongside macOS.
check pass rapid "$(variant "$recommit" '.name | startswith("windows-")' "$never_started")" "$not_acquired"
shows '::warning title=Tests skipped::Never started, for want of a runner, so not run: macos-latest, Python 3.15; windows-latest, Python 3.15' "$tmp/out"
# Beside a project.yml job that skipped itself.
check pass rapid "$(variant "$recommit" '.name | startswith("project / ")' \
  '.conclusion = "skipped" | .runner_name = "" | .steps = []')" "$not_acquired"
# All tests passed: nothing to say.
check pass rapid "$(variant "$recommit" '.name | startswith("macos-")' '.conclusion = "success"')" \
  "$tmp/none.json" TESTS=success
if [ -s "$tmp/summary" ] || [ -s "$tmp/out" ]; then
  echo "FAIL: output or a summary when all tests passed:"
  cat "$tmp/out" "$tmp/summary"
  failures=$((failures + 1))
fi

# Not out of rapid development, nor on main.
check fail strict "$recommit" "$not_acquired"
check fail rapid "$recommit" "$not_acquired" EVENT=push
# Not a job that ran (got a runner, or started a step) and then timed out, nor one cancelled
# with its run before it started.
check fail rapid "$(variant "$recommit" '.name | startswith("macos-")' "$got_runner")" "$not_acquired"
check fail rapid "$(variant "$recommit" '.name | startswith("macos-")' "$started_step")" "$not_acquired"
check fail rapid "$recommit" "$tmp/superseded.json"
check fail rapid "$recommit" "$tmp/none.json"
# Not Linux, which must have run and passed: not a Linux job that never started, or failed, or
# a run without one.
check fail rapid "$(variant "$recommit" '.name | startswith("ubuntu-")' "$never_started")" "$not_acquired"
check fail rapid "$(variant "$recommit" '.name | startswith("ubuntu-")' '.conclusion = "failure"')" "$not_acquired"
jq 'del(.jobs[] | select(.name | startswith("ubuntu-")))' "$recommit" > "$tmp/no-linux.json"
check fail rapid "$tmp/no-linux.json" "$not_acquired"
# Not a macOS or Windows job that failed, beside one that never started.
check fail rapid "$(variant "$stack" '.name == "macos-latest, Python 3.15 (2/2)"' '.conclusion = "failure"')" "$not_acquired"
check fail rapid "$(variant "$stack" '.name | startswith("windows-")' '.conclusion = "failure"')" "$not_acquired"
# Not a test job on another runner the project added, which failed.
jq '.jobs += [{"id": 1, "name": "ubuntu-24.04-arm, Python 3.15", "status": "completed",
  "conclusion": "failure", "runner_name": "GitHub Actions 2", "steps": []}]' "$recommit" \
  > "$tmp/other-runner.json"
check fail rapid "$tmp/other-runner.json" "$not_acquired"
# Not the other checks, nor project.yml's jobs (whatever system they run on).
check fail rapid "$recommit" "$not_acquired" STATIC=abandoned
check fail rapid "$recommit" "$not_acquired" COVERAGE=failure
check fail rapid "$(variant "$recommit" '.name | startswith("project / ")' "$never_started")" \
  "$not_acquired" PROJECT=abandoned
# Docs alone changed: the tests didn't run, and needn't have.
check pass rapid "$recommit" "$tmp/none.json" CODE=false TESTS=skipped STATIC=skipped COVERAGE=skipped

if [ "$failures" != 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "All passed."
