#!/usr/bin/env bash
set -euo pipefail

repo_api="https://api.github.com/repos/LadybirdBrowser/ladybird/commits/master"

json="$(curl -fsSL \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "$repo_api")"

readarray -t commit_data < <(
  python3 -c '
import json, sys
data = json.loads(sys.stdin.read())
print(data["sha"])
print(data["commit"]["committer"]["date"][:10])
' <<<"$json"
)

rev="${commit_data[0]}"
version_date="${commit_data[1]}"
archive_url="https://github.com/LadybirdBrowser/ladybird/archive/${rev}.tar.gz"

echo "Resolved upstream master:"
echo "  rev: ${rev}"
echo "  date: ${version_date}"

src_hash_raw="$(nix-prefetch-url --type sha256 --unpack "$archive_url")"
src_hash="$(nix hash convert --hash-algo sha256 --to sri "$src_hash_raw")"

fake_cargo_hash='sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='

echo "Prefetched source hash:"
echo "  ${src_hash}"

export LADYBIRD_REV="$rev"
export LADYBIRD_VERSION_DATE="$version_date"
export LADYBIRD_SRC_HASH="$src_hash"
export LADYBIRD_CARGO_HASH="$fake_cargo_hash"

set +e
first_build_output="$(nix build .#ladybird --impure --no-link 2>&1)"
first_build_status=$?
set -e

if [[ $first_build_status -eq 0 ]]; then
  echo "Expected the first build to fail while discovering cargoHash, but it succeeded."
  exit 1
fi

cargo_hash="$(
  printf '%s\n' "$first_build_output" |
    sed -n 's/.*got:[[:space:]]*\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' |
    tail -n1
)"

if [[ -z "$cargo_hash" ]]; then
  echo "Failed to extract cargoHash from the first build output."
  printf '%s\n' "$first_build_output"
  exit 1
fi

echo "Resolved cargo hash:"
echo "  ${cargo_hash}"

export LADYBIRD_CARGO_HASH="$cargo_hash"

nix build .#ladybird --impure --print-build-logs

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## Ladybird upstream build"
    echo
    echo "- Commit: \`${rev}\`"
    echo "- Date: \`${version_date}\`"
    echo "- Source hash: \`${src_hash}\`"
    echo "- Cargo hash: \`${cargo_hash}\`"
  } >>"$GITHUB_STEP_SUMMARY"
fi
