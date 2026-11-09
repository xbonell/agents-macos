# Shared by sync-upstream.sh and check-upstream.sh: where the Omarchy
# checkout is, and which of its collectors this port vendors.
UPSTREAM_DEFAULT="${OMARCHY_CHECKOUT:-$HOME/Work/99.misc/omarchy}"
PROVIDERS=(claude codex cursor grokbot opencode)

# The upstream paths vendored, relative to the Omarchy checkout, each with
# where it lands relative to Sources/Agents/Resources.
vendored_files() {
  echo "shell/plugins/agents/collectors.py collectors/shell/plugins/agents/collectors.py"
  local id mark
  for id in "${PROVIDERS[@]}"; do
    echo "bin/omarchy-agent-usage-$id collectors/bin/omarchy-agent-usage-$id"
    for mark in "$id.svg" "$id-light.svg"; do
      echo "shell/plugins/agents/assets/$mark assets/$mark"
    done
  done
}

# Stop with a hint when the path isn't an Omarchy checkout, instead of
# reading every vendored file as gone upstream.
require_checkout() {
  [[ -d $1/.git && -d $1/shell/plugins/agents ]] && return
  echo "No Omarchy checkout at $1." >&2
  echo "Clone https://github.com/omacom/omarchy, then pass its path or set OMARCHY_CHECKOUT." >&2
  exit 2
}
