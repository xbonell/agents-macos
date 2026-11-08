"""Run one vendored collector with the macOS shim applied.

  python3 run_collector.py <id> [--force] [--limits-only]

Prints the collector's record on stdout, exactly as the collector does.
"""

from __future__ import annotations

import os
import runpy
import sys
from pathlib import Path

sys.dont_write_bytecode = True

HERE = Path(__file__).resolve().parent
VENDOR = HERE.parent / "collectors"
HOME = Path.home()


def main() -> int:
  if len(sys.argv) < 2:
    print("usage: run_collector.py <id> [--force] [--limits-only]", file=sys.stderr)
    return 2
  agent_id = sys.argv[1]
  script = VENDOR / "bin" / f"omarchy-agent-usage-{agent_id}"
  if not script.is_file():
    print(f"run_collector: no collector named {agent_id}", file=sys.stderr)
    return 2

  os.environ["OMARCHY_PATH"] = str(VENDOR)
  os.environ.setdefault("XDG_STATE_HOME", str(HOME / "Library" / "Application Support" / "Agents"))
  os.environ.setdefault("XDG_CACHE_HOME", str(HOME / "Library" / "Caches" / "Agents"))

  sys.path.insert(0, str(VENDOR / "shell" / "plugins" / "agents"))
  sys.path.insert(0, str(HERE))
  # macOS ships Python 3.9; tomllib (3.11) is tomli upstreamed, so the
  # vendored tomli stands in for it under the same name.
  try:
    import tomllib  # noqa: F401
  except ModuleNotFoundError:
    sys.path.insert(0, str(HERE / "vendor"))
    import tomli

    sys.modules["tomllib"] = tomli
  import macos_shim

  macos_shim.apply()

  sys.argv = [str(script), *sys.argv[2:]]
  runpy.run_path(str(script), run_name="__main__")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
