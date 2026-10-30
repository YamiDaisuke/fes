#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <site-path> [<built-dir>]" >&2
  echo "  <site-path> is . for main or pr/<number>; without <built-dir> the folder is deleted" >&2
  exit 2
}

site_path=${1:-}
built_dir=${2:-}
[[ "$site_path" == "." || "$site_path" =~ ^pr/[0-9]+$ ]] || usage
[[ -z "$built_dir" || -d "$built_dir" ]] || usage

site=$(mktemp -d)
trap 'rm -rf "$site"' EXIT

for attempt in 1 2 3 4 5; do
  rm -rf "$site" && mkdir -p "$site"
  if git fetch -q --depth 1 origin gh-pages; then
    expected=$(git rev-parse FETCH_HEAD)
    git archive FETCH_HEAD | tar -x -C "$site"
  else
    # An empty lease means the push only succeeds if gh-pages doesn't exist yet.
    expected=""
  fi

  if [[ "$site_path" == "." ]]; then
    find "$site" -mindepth 1 -maxdepth 1 ! -name pr -exec rm -rf {} +
  else
    rm -rf "${site:?}/$site_path"
  fi
  if [[ -n "$built_dir" ]]; then
    mkdir -p "$site/$site_path"
    cp -R "$built_dir/." "$site/$site_path/"
  fi

  git -C "$site" init -q
  git -C "$site" add -A
  git -C "$site" -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit -q --allow-empty -m "Publish $site_path"
  git fetch -q "$site" HEAD
  git push --force-with-lease="gh-pages:$expected" origin FETCH_HEAD:refs/heads/gh-pages && exit 0
  sleep $((attempt * 5))
done
echo "gh-pages kept changing; gave up after 5 attempts" >&2
exit 1
