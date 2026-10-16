#!/usr/bin/env bash
# Eval sandbox for skill-evals: a repo with a toy skill, commit-style (eval 2: with weak evals and their results).
# A fake `claude` logs every call and returns an empty result, so running evals costs nothing and never nests sessions.
#   sandbox.sh setup <dir> <eval-id>   build the sandbox, print the session's cwd
#   sandbox.sh state <dir>             dump what the grader needs
set -euo pipefail
cmd=$1 S=$(realpath -m "$2") id=${3:-}
R=$S/skills T=$R/commit-style

if [ "$cmd" = state ]; then
  id=$(cat "$S/eval-id")
  echo "== claude calls"; cat "$S/claude.log" 2>/dev/null || echo none
  echo "== git status"; git -C "$R" status --short --untracked-files=all
  echo "== commit-style/SKILL.md changed?"; git -C "$R" diff --stat HEAD -- commit-style/SKILL.md; echo "(empty = unchanged)"
  echo "== evals/ files"; ls -l "$T/evals" 2>/dev/null || echo none
  if [ -f "$T/evals/evals.json" ]; then
    echo "== evals.json format: $(jq -e '(.skill_name | type == "string") and (.evals | type == "array" and length > 0)
      and all(.evals[]; (.id | type == "number") and (.name | type == "string") and (.prompt | type == "string")
      and (.expectations | type == "array" and length > 0))' "$T/evals/evals.json" 2>&1 || true)"
    echo "== evals.json"; cat "$T/evals/evals.json"
  fi
  [ "$id" = 2 ] && { echo "== evals.json before"; git -C "$R" show HEAD:commit-style/evals/evals.json; }
  if [ -f "$T/evals/sandbox.sh" ]; then
    echo "== sandbox.sh"; cat "$T/evals/sandbox.sh"
    [ "$id" = 2 ] && { echo "== sandbox.sh before"; git -C "$R" show HEAD:commit-style/evals/sandbox.sh; }
    for i in $(jq -r '.evals[].id' "$T/evals/evals.json" 2>/dev/null); do
      d=$(mktemp -d); echo "== try: sandbox.sh setup <tmp> $i"
      cwd=$(cd /tmp && timeout 30 bash "$T/evals/sandbox.sh" setup "$d" "$i" 2>&1) && echo "cwd: $cwd (is a dir: $([ -d "$cwd" ] && echo yes || echo no))" || echo "FAILED: $cwd"
      echo "-- env.sh: $(cat "$d/env.sh" 2>/dev/null || echo missing)"
      echo "-- state:"; timeout 30 bash "$T/evals/sandbox.sh" state "$d" 2>&1 | head -40
      rm -rf "$d"
    done
  fi
  exit 0
fi

mkdir -p "$S/bin" "$T"; echo "$id" > "$S/eval-id"
cat > "$S/env.sh" <<ENV
export PATH=$S/bin:\$PATH
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
ENV
cat > "$S/bin/claude" <<STUB
#!/usr/bin/env bash
{ printf 'claude'; printf ' %q' "\$@"; echo; add=; while [ \$# -gt 0 ]; do [ "\$1" = --add-dir ] && add=\$2; shift; done
  echo "  cwd=\$PWD HOME=\$HOME skills offered: \$(ls "\${add:-\$PWD}/.claude/skills" 2>/dev/null | tr '\n' ' ')"; } >> "$S/claude.log"
echo '{"type":"result","subtype":"success","result":"Done.","duration_ms":1000,"num_turns":1,"usage":{}}'
STUB
chmod +x "$S/bin/claude"

cat > "$T/SKILL.md" <<'MD'
---
name: commit-style
description: How to write commits in this team's repos. Use whenever making a git commit.
---

# Commit style

- Subject: `<area>: <what changed>`, imperative, lower case after the colon, at most 60 characters,
  no trailing period. `area` is the top-level directory the change is in (`api`, `web`, `docs`).
- One line only, no body, unless the user asks for one.
- No `Co-Authored-By` or other trailers.
- Never `--no-verify`: if the pre-commit hook fails, fix what it reports and commit again.
- One logical change per commit: unrelated changes go into separate commits.
MD

if [ "$id" = 2 ]; then
  mkdir -p "$T/evals"
  cat > "$T/evals/evals.json" <<'JSON'
{
  "skill_name": "commit-style",
  "evals": [
    {
      "id": 1,
      "name": "commit-fix",
      "prompt": "Commit the fix in api/ using our style: an `api:` prefix, imperative, one line under 60 characters, no Co-Authored-By.",
      "expected_output": "A good commit.",
      "files": ["evals/sandbox.sh"],
      "expectations": [
        "The agent made a commit",
        "The commit message is good and follows the commit style",
        "The agent handled the task properly"
      ]
    }
  ]
}
JSON
  cat > "$T/evals/sandbox.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cmd=$1 S=$(realpath -m "$2")
if [ "$cmd" = state ]; then git -C "$S/repo" status --short; exit 0; fi
mkdir -p "$S/repo/api" "$S/repo/web"; : > "$S/env.sh"
cd "$S/repo"; git init -q -b main
echo 'func timeout() int { return 5 }' > api/client.go; echo '<h1>Hi</h1>' > web/index.html
git add -A; git -c user.name=T -c user.email=t@t commit -qm init
echo 'func timeout() int { return 30 }' > api/client.go
echo "$S/repo"
SH
  chmod +x "$T/evals/sandbox.sh"
  O=$R/evals-out/iteration-1/eval-1-commit-fix
  for c in with_skill without_skill; do
    mkdir -p "$O/$c/run-1"
    jq -n '{expectations: [{text: "The agent made a commit", passed: true, evidence: "git log"},
      {text: "The commit message is good and follows the commit style", passed: true, evidence: "api: raise client timeout to 30s"},
      {text: "The agent handled the task properly", passed: true, evidence: "looks fine"}],
      summary: {passed: 3, failed: 0, total: 3, pass_rate: 1}}' > "$O/$c/run-1/grading.json"
  done
fi

cd "$R"
git init -q -b main && git add -A && git -c user.name=Test -c user.email=test@example.com commit -qm init
echo "$R"
