#!/usr/bin/python3
"""Write made-up usage records, one per provider, for the panel to draw.

  scripts/make-samples.py <dir>
  AGENTS_USAGE_DIR=<dir> .build/debug/Agents --snapshot panel.png [--dark]

Reset times and the week's history are relative to now, so the records never
go stale the way fixed files would (an elapsed window reads 0%). Nothing here
comes from a real account.
"""

import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

NOW = datetime.now(timezone.utc)


def at(**delta) -> str:
  return (NOW + timedelta(**delta)).isoformat()


def week(*tokens: int) -> dict:
  # Oldest day first, ending today, as the collectors write recentDays.
  days = [(NOW - timedelta(days=len(tokens) - 1 - i)).date().isoformat() for i in range(len(tokens))]
  return {
    "recentDays": [{"date": d, "messageCount": t} for d, t in zip(days, tokens)],
    "activeDates": [d for d, t in zip(days, tokens) if t],
    "activeDays": sum(1 for t in tokens if t),
    "todayTotalTokens": tokens[-1],
  }


def record(id: str, name: str, tier: str, limits: list, **extra) -> dict:
  base = {
    "schemaVersion": 1, "id": id, "name": name, "updatedAt": NOW.isoformat(),
    "ready": True, "hasLocalStats": False, "hasPromptStats": False, "tierLabel": tier,
    "usageStatusText": "", "authHelpText": "", "limits": limits, "limitsStale": False,
    "limitsFetchedAt": int(NOW.timestamp() * 1000), "todayPrompts": 0, "todaySessions": 0,
    "todayTotalTokens": 0, "totalPrompts": 0, "totalSessions": 0, "activeDays": 0,
    "activeDates": [], "recentDays": [], "modelUsage": {}, "todayTokensByModel": {},
  }
  base.update(extra)
  return base


SAMPLES = [
  record("claude", "Claude Code", "Max", [
    {"label": "Session (5-hour)", "percent": 0.34, "resetsAt": at(hours=2, minutes=10)},
    {"label": "Weekly (7-day)", "percent": 0.61, "resetsAt": at(days=3, hours=4)},
    {"label": "Fable Weekly", "title": "Fable Weekly", "percent": 0.12, "resetsAt": at(days=3, hours=4)},
  ], hasLocalStats=True, hasPromptStats=True, todayPrompts=41, todaySessions=6,
    totalPrompts=212, totalSessions=27,
    **week(8_400_000, 12_100_000, 0, 9_800_000, 15_300_000, 11_000_000, 6_200_000)),
  record("codex", "Codex", "Plus", [
    {"label": "5h window", "percent": 0.08, "resetsAt": at(hours=4, minutes=22)},
    {"label": "Weekly (7-day)", "percent": 0.27, "resetsAt": at(days=5, hours=21)},
  ], hasLocalStats=True, hasPromptStats=True, todayPrompts=9, todaySessions=2,
    totalPrompts=48, totalSessions=11,
    **week(0, 2_300_000, 1_100_000, 0, 3_400_000, 900_000, 1_700_000)),
  record("cursor", "Cursor", "Pro", [
    {"label": "Included total", "title": "Monthly", "percent": 0.93, "resetsAt": at(days=3)},
    {"label": "Auto models", "title": "Auto models Monthly", "percent": 0.88, "resetsAt": at(days=3)},
    {"label": "Named models", "title": "Named models Monthly", "percent": 0.96, "resetsAt": at(days=3)},
  ], hasLocalStats=True, scope="account",
    **week(600_000, 900_000, 400_000, 0, 1_200_000, 700_000, 300_000)),
  record("grokbot", "Grok Bot", "Grok Bot Plan", [
    {"label": "Weekly", "percent": 0.19, "resetsAt": at(days=4, hours=7)},
  ]),
  record("opencode", "OpenCode", "Zen", [],
    balance={"remaining": 13.4, "funded": 20.0, "spent": 6.6, "currency": "USD", "estimated": False},
    hasPromptStats=True, todayPrompts=3, todaySessions=1, totalPrompts=14, totalSessions=4),
]


def main() -> int:
  if len(sys.argv) != 2:
    print(__doc__.strip(), file=sys.stderr)
    return 2
  out = Path(sys.argv[1])
  out.mkdir(parents=True, exist_ok=True)
  for sample in SAMPLES:
    (out / f"{sample['id']}.json").write_text(json.dumps(sample, indent=2) + "\n")
  print(f"Wrote {len(SAMPLES)} records to {out}")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
