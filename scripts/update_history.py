#!/usr/bin/env python3
"""
Maintain docs/history.json — a rolling list of the last N build metadata objects,
newest first. Used by the GitHub Pages status dashboard.
"""
import json
import os
import sys

NEW_FILE = os.environ.get("NEW_FILE", "build-info/meta.json")
HISTORY_FILE = os.environ.get("HISTORY_FILE", "docs/history.json")
KEEP = int(os.environ.get("KEEP", "50"))


def main() -> int:
    if not os.path.exists(NEW_FILE):
        print(f"ERROR: {NEW_FILE} not found", file=sys.stderr)
        return 1

    new_entry = json.load(open(NEW_FILE))
    history = []

    if os.path.exists(HISTORY_FILE) and os.path.getsize(HISTORY_FILE) > 2:
        try:
            history = json.load(open(HISTORY_FILE))
            if not isinstance(history, list):
                history = []
        except json.JSONDecodeError:
            history = []

    # Dedupe by run_id so re-runs don't pile up
    history = [h for h in history if h.get("run_id") != new_entry.get("run_id")]
    history.insert(0, new_entry)
    history = history[:KEEP]

    os.makedirs(os.path.dirname(HISTORY_FILE), exist_ok=True)
    with open(HISTORY_FILE, "w") as fh:
        json.dump(history, fh, indent=2)
    print(f"Wrote {HISTORY_FILE} with {len(history)} build(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
