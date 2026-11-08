# Shared by sync-upstream.sh and check-upstream.sh: where the Omarchy
# checkout is, and which of its collectors this port vendors.
UPSTREAM_DEFAULT="$HOME/Work/99.misc/omarchy"
PROVIDERS=(claude codex cursor opencode)

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
