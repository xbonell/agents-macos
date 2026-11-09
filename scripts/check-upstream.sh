#!/bin/bash
# Says whether the vendored collectors and marks differ from Omarchy, and
# which upstream commits touched them since the last sync. Never changes the
# checkout's files.
#
#   scripts/check-upstream.sh                 # against the checkout's files
#   scripts/check-upstream.sh --fetch         # fetch, then against its tracked branch
#   scripts/check-upstream.sh --ref upstream/master   # against any ref (fetch it first)
#   scripts/check-upstream.sh [options] /path/to/omarchy
#
# Exits 0 when everything matches, 1 when there's something to sync, 2 when
# there's no checkout.
set -euo pipefail

source "$(dirname "$0")/upstream.sh"
RESOURCES="$(cd "$(dirname "$0")/.." && pwd)/Sources/Agents/Resources"
UPSTREAM="$UPSTREAM_DEFAULT"
REF=""
FETCH=0

while (( $# > 0 )); do
  case "$1" in
  --fetch) FETCH=1 ;;
  --ref) REF="$2"; shift ;;
  *) UPSTREAM="$1" ;;
  esac
  shift
done

require_checkout "$UPSTREAM"
git_up() { git -C "$UPSTREAM" "$@"; }

if (( FETCH )); then
  git_up fetch --quiet
  [[ -n $REF ]] || REF="$(git_up rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')"
fi

# A file as upstream has it: from a ref, or the checkout's working tree.
upstream_file() {
  if [[ -n $REF ]]; then
    git_up show "$REF:$1" 2>/dev/null
  else
    cat "$UPSTREAM/$1" 2>/dev/null
  fi
}

if [[ -n $REF ]]; then
  echo "Comparing with $REF in $UPSTREAM"
else
  echo "Comparing with the working tree of $UPSTREAM"
fi
changed=0
paths=()
while read -r from to; do
  local_file="$RESOURCES/$to"
  if ! upstream_file "$from" >/dev/null; then
    # A mark a provider doesn't ship is fine; a vanished collector isn't.
    if [[ -f $local_file ]]; then echo "  gone upstream  $from"; changed=1; fi
    continue
  fi
  paths+=("$from")
  if [[ ! -f $local_file ]]; then
    echo "  new upstream   $from"; changed=1
  elif ! cmp -s <(upstream_file "$from") "$local_file"; then
    echo "  changed        $from"; changed=1
  fi
done < <(vendored_files)

if (( ! changed )); then
  echo "  everything matches"
fi

synced="$(cat "$RESOURCES/collectors/UPSTREAM_REVISION" 2>/dev/null || echo unknown)"
if [[ $synced != unknown ]] && git_up cat-file -e "$synced^{commit}" 2>/dev/null; then
  log="$(git_up log --oneline "$synced..${REF:-HEAD}" -- "${paths[@]}")"
  if [[ -n $log ]]; then
    echo
    echo "Upstream commits touching them since the last sync (${synced:0:7}):"
    echo "$log" | sed 's/^/  /'
  fi
fi

if (( changed )); then
  echo
  echo "To take them: scripts/sync-upstream.sh $UPSTREAM  (then build, run each collector, snapshot)"
fi
exit "$changed"
