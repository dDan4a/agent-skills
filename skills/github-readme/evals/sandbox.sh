#!/usr/bin/env bash
# Eval sandbox for github-readme: a small Go CLI repo with a plain README, a benchmark CSV and a screenshot.
# A fake `gh` logs calls and is not logged in; origin points at GitHub but nothing can be pushed from the sandbox.
#   sandbox.sh setup <dir> <eval-id>   build the sandbox, print the session's cwd
#   sandbox.sh state <dir>             dump what the grader needs
set -euo pipefail
cmd=$1 S=$(realpath -m "$2") id=${3:-}
R=$S/jsonslim

if [ "$cmd" = state ]; then
  echo "== gh calls"; cat "$S/gh.log" 2>/dev/null || echo none
  echo "== git status"; git -C "$R" status --short
  echo "== new or changed files"; git -C "$R" status --short --untracked-files=all | awk '{print $2}' | while read -r f; do
    case $f in *.svg) echo "-- $f (first 15 lines)"; head -15 "$R/$f" ;; *.md|*.py|*.sh) echo "-- $f"; cat "$R/$f" ;; *) echo "-- $f" ;; esac
  done
  echo "== README.md before"; git -C "$R" show HEAD:README.md
  exit 0
fi

mkdir -p "$S/bin" "$R/docs" "$R/bench" "$R/.github/workflows" "$R/cmd/jsonslim"
cat > "$S/env.sh" <<ENV
export PATH=$S/bin:\$PATH
ENV
cat > "$S/bin/gh" <<STUB
#!/usr/bin/env bash
printf 'gh' >> "$S/gh.log"; printf ' %q' "\$@" >> "$S/gh.log"; echo >> "$S/gh.log"
echo "To get started with GitHub CLI, please run:  gh auth login" >&2; exit 4
STUB
chmod +x "$S/bin/gh"

cd "$R"
cat > README.md <<'MD'
# jsonslim

jsonslim minifies and filters JSON from the command line. It is a single static binary, streams input so it works on files bigger than memory, and is faster than jq for plain minification.

## Install

    go install github.com/acme/jsonslim/cmd/jsonslim@latest

Or download a binary from the Releases page.

## Usage

    jsonslim < big.json > small.json
    jsonslim --keep name,email users.json
    curl -s https://api.example.com/items | jsonslim --drop meta

Options:

- `--keep a,b` keep only these top-level keys
- `--drop a,b` remove these top-level keys
- `--indent N` pretty-print with N spaces instead of minifying
- `--stream` treat input as newline-delimited JSON

There is a screenshot in docs/demo.png.

## Benchmark

We measured minifying a 1 GB file on a Ryzen 7 7840U, see bench/results.csv. jsonslim is about 3x faster than jq.

## How it works

The input goes through a tokenizer, then the filter, then the writer. Nothing is kept in memory except the current key path.

## Contributing

Run `go test ./...` before sending a PR. Issues and PRs welcome.

## License

MIT
MD
cat > bench/results.csv <<'CSV'
tool,seconds,peak_mb
jsonslim,2.1,6
jq,6.8,1890
python json.tool,14.2,3120
node JSON.stringify,4.9,2410
CSV
printf 'MIT License\n\nCopyright (c) 2026 acme\n' > LICENSE
printf 'module github.com/acme/jsonslim\n\ngo 1.23\n' > go.mod
printf 'package main\n\nfunc main() {}\n' > cmd/jsonslim/main.go
cat > .github/workflows/ci.yml <<'YML'
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
      - run: go test ./...
YML
# A 960x540 dark PNG standing in for a terminal screenshot (a 1x1 one reads as a placeholder and gets left out).
python3 -c 'import struct,zlib,sys
w,h=960,540; c=lambda t,d: struct.pack(">I",len(d))+t+d+struct.pack(">I",zlib.crc32(t+d))
raw=b"".join(b"\0"+b"\x1e\x1e\x2e"*w for _ in range(h))
sys.stdout.buffer.write(b"\x89PNG\r\n\x1a\n"+c(b"IHDR",struct.pack(">IIBBBBB",w,h,8,2,0,0,0))+c(b"IDAT",zlib.compress(raw))+c(b"IEND",b""))' > docs/demo.png
git init -q -b main && git remote add origin https://github.com/acme/jsonslim.git
git add -A && git -c user.name=acme -c user.email=dev@acme.test commit -qm init
echo "$R"
