"""macOS differences for the vendored Omarchy collectors.

The collectors are copied unmodified from Omarchy; everything that differs on
macOS is patched onto the shared `collectors` module here, before a collector
script imports names from it. Credentials are only ever read, as the
collector contract requires.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any

import collectors

APP_SUPPORT = Path.home() / "Library" / "Application Support"

_read_json = collectors.read_json


def keychain_secret(service: str, account: str = "") -> str:
  """A generic password from the login Keychain, "" when absent or denied."""
  command = ["/usr/bin/security", "find-generic-password", "-s", service]
  if account:
    command += ["-a", account]
  try:
    found = subprocess.run(
      [*command, "-w"],
      capture_output=True, text=True, timeout=10,
    )
  except (OSError, subprocess.TimeoutExpired):
    return ""
  return found.stdout.strip() if found.returncode == 0 else ""


def _keychain_json(service: str, account: str = "") -> dict[str, Any]:
  try:
    parsed = json.loads(keychain_secret(service, account) or "{}")
  except ValueError:
    return {}
  return parsed if isinstance(parsed, dict) else {}


def read_json(path: Path) -> dict[str, Any]:
  parsed = _read_json(path)
  if parsed:
    return parsed
  # Claude Code on macOS keeps .credentials.json's content in the Keychain.
  if path.name == ".credentials.json":
    return _keychain_json("Claude Code-credentials")
  # cursor-agent on macOS keeps its tokens in the Keychain, not auth.json.
  if path == collectors.cursor_auth_path():
    token = keychain_secret("cursor-access-token")
    return {"accessToken": token} if token else {}
  # agy asks secret-tool for its sign-in; on macOS the same keyring entry
  # (service gemini, account antigravity) lives in the Keychain.
  if path.name == "antigravity-oauth-token":
    return _keychain_json("gemini", "antigravity")
  return parsed


def cursor_state_db() -> Path:
  return APP_SUPPORT / "Cursor" / "User" / "globalStorage" / "state.vscdb"


def apply() -> None:
  collectors.read_json = read_json
  collectors.cursor_state_db = cursor_state_db
