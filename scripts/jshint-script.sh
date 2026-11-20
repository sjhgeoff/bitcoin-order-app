#!/usr/bin/env bash
set -euo pipefail
files=()
while IFS= read -r -d '' file; do files+=("$file"); done < <(git ls-files -z -- '*.js')
if (( ${#files[@]} == 0 )); then echo 'No tracked JavaScript found' >&2; exit 1; fi
status=0
{
  jshint --version
  printf 'Commit: %s\nJavaScript files checked: %s\n' "$(git rev-parse --short HEAD)" "${#files[@]}"
  printf '  %s\n' "${files[@]}"
  printf '\n'
  jshint --reporter=unix "${files[@]}" || status=$?
} > JSHint-report
case $status in
  0) echo 'No JSHint findings.' >> JSHint-report ;;
  2) ;; # JSHint completed and reported findings.
  *) exit "$status" ;;
esac
cat JSHint-report
