#!/usr/bin/python3
"""Write made-up usage records, one per provider, for the panel to draw.

  scripts/make-samples.py [--only id,id,...] <dir>
  AGENTS_USAGE_DIR=<dir> .build/debug/Agents --snapshot panel.png [--dark]

Reset times and the week's history are relative to now, so the records never
go stale the way fixed files would (an elapsed window reads 0%). Nothing here
comes from a real account. --only keeps the named providers: the README's
screenshots are the first five, since every card together scrolls.
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
  record("agy", "Antigravity", "Pro", [
    {"label": "5h window", "percent": 0.22, "resetsAt": at(hours=3, minutes=5)},
    {"label": "Weekly", "percent": 0.48, "resetsAt": at(days=2, hours=9)},
  ], hasLocalStats=True, **week(0, 1_300_000, 2_100_000, 0, 900_000, 1_600_000, 700_000)),
  record("copilot", "GitHub Copilot", "Pro", [
    {"label": "Monthly", "percent": 0.37, "resetsAt": at(days=18)},
  ], hasLocalStats=True, **week(200_000, 0, 450_000, 380_000, 0, 520_000, 160_000)),
  record("deepseek", "DeepSeek", "", [],
    balance={"remaining": 7.85, "funded": 10.0, "spent": 2.15, "currency": "USD", "estimated": False}),
  record("devin", "Devin", "Core", [
    {"label": "Monthly", "percent": 0.55, "resetsAt": at(days=11)},
  ]),
  record("fireworks", "Fireworks", "", [],
    balance={"remaining": 41.2, "funded": 50.0, "spent": 8.8, "currency": "USD", "estimated": False}),
  record("grok", "Grok", "SuperGrok", [
    {"label": "Weekly", "percent": 0.31, "resetsAt": at(days=4, hours=2)},
  ]),
  record("hermes", "Hermes", "", [], hasPromptStats=True, todayPrompts=5, todaySessions=2,
    totalPrompts=23, totalSessions=7),
  record("kimchi", "Kimchi", "", [],
    balance={"remaining": 3.1, "funded": 25.0, "spent": 21.9, "currency": "USD", "estimated": False}),
  record("kimi", "Kimi", "Moderato", [
    {"label": "5h window", "percent": 0.12, "resetsAt": at(hours=1, minutes=40)},
    {"label": "Weekly", "percent": 0.29, "resetsAt": at(days=6)},
  ]),
  record("local", "Local models", "", [], hasLocalStats=True,
    **week(0, 0, 320_000, 0, 610_000, 0, 240_000)),
  record("minimax", "MiniMax", "Plus", [
    {"label": "5h window", "percent": 0.66, "resetsAt": at(hours=2, minutes=50)},
  ]),
  record("muse", "Muse", "Free", [
    {"label": "Daily", "percent": 0.4, "resetsAt": at(hours=9)},
  ]),
  record("ollama", "Ollama Cloud", "Pro", [
    {"label": "Session", "percent": 0.05, "resetsAt": at(hours=3)},
    {"label": "Weekly", "percent": 0.18, "resetsAt": at(days=5)},
  ]),
  record("openrouter", "OpenRouter", "", [],
    balance={"remaining": 18.6, "funded": 30.0, "spent": 11.4, "currency": "USD", "estimated": False}),
  record("qwen", "Qwen Code", "", [], hasPromptStats=True, todayPrompts=2, todaySessions=1,
    totalPrompts=9, totalSessions=3),
  record("synthetic", "Synthetic", "Standard", [
    {"label": "5h window", "percent": 0.91, "resetsAt": at(hours=1, minutes=12)},
  ]),
  record("vibe", "Mistral Vibe", "", [], hasPromptStats=True, todayPrompts=0, todaySessions=0,
    totalPrompts=6, totalSessions=2),
  record("zai", "Z.ai", "Lite", [
    {"label": "5h window", "percent": 0.44, "resetsAt": at(hours=4)},
    {"label": "Monthly", "percent": 0.2, "resetsAt": at(days=21)},
  ]),
]


def main() -> int:
  args = sys.argv[1:]
  only = None
  if len(args) == 3 and args[0] == "--only":
    only = set(args[1].split(","))
    args = args[2:]
  if len(args) != 1:
    print(__doc__.strip(), file=sys.stderr)
    return 2
  out = Path(args[0])
  out.mkdir(parents=True, exist_ok=True)
  samples = [s for s in SAMPLES if only is None or s["id"] in only]
  for sample in samples:
    (out / f"{sample['id']}.json").write_text(json.dumps(sample, indent=2) + "\n")
  print(f"Wrote {len(samples)} records to {out}")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
