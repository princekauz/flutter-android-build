#!/usr/bin/env python3
"""
Read apks.txt produced by the build workflow and emit build-info/meta.json.

apks.txt format: one line per APK, pipe-separated:
    filename|size|sha256|package|version
"""
import json
import os
import sys
from datetime import datetime, timezone

APKS_FILE = os.environ.get("APKS_FILE", "build-info/apks.txt")
OUT_FILE = os.environ.get("OUT_FILE", "build-info/meta.json")


def main() -> int:
    if not os.path.exists(APKS_FILE):
        print(f"ERROR: {APKS_FILE} not found", file=sys.stderr)
        return 1

    apks = []
    with open(APKS_FILE) as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            fname, size, sha, pkg, ver = line.split("|")
            apks.append({
                "file": fname,
                "size": int(size),
                "sha256": sha,
                "package": pkg,
                "version": ver,
            })

    meta = {
        "run_id": os.environ.get("RUN_ID", ""),
        "run_number": int(os.environ.get("RUN_NUMBER", "0")),
        "workflow": os.environ.get("WORKFLOW", ""),
        "ref": os.environ.get("REF", ""),
        "ref_name": os.environ.get("REF_NAME", ""),
        "sha": os.environ.get("SHA", ""),
        "short_sha": os.environ.get("SHA_SHORT", ""),
        "commit_message": os.environ.get("COMMIT_MESSAGE", "").replace("\n", " "),
        "commit_author": os.environ.get("COMMIT_AUTHOR", ""),
        "actor": os.environ.get("ACTOR", ""),
        "build_mode": os.environ.get("BUILD_MODE", "release"),
        "split_per_abi": os.environ.get("SPLIT_PER_ABI", "true"),
        "flutter_version": os.environ.get("FLUTTER_VERSION", ""),
        "java_version": os.environ.get("JAVA_VERSION", ""),
        "started_at": os.environ.get("STARTED_AT", ""),
        "finished_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "repository": os.environ.get("REPOSITORY", ""),
        "server_url": os.environ.get("SERVER_URL", ""),
        "conclusion": os.environ.get("CONCLUSION", "success"),
        "apks": apks,
    }

    with open(OUT_FILE, "w") as fh:
        json.dump(meta, fh, indent=2)
    print(f"Wrote {OUT_FILE} with {len(apks)} APK(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
