#!/usr/bin/env python3
"""aggregate-results: collect per-repo result.json from a fan-out workspace.

Usage:
  python3 aggregate.py --run-id <id>

--run-id    The run identifier; workspace is ~/.forge-cross-repo/<run-id>/.

Walks each <repo>/result.json in the workspace, builds a verdict matrix,
de-duplicates summaries by content hash, writes aggregated.json, and appends
an aggregate_complete ledger entry.
"""

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


WORKSPACE_ROOT = Path.home() / ".forge-cross-repo"


def ts() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256_short(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]


def verdict_for(result: dict) -> str:
    status = result.get("status", "")
    if status == "complete":
        exit_code = result.get("exit_code", 0)
        return "PASS" if exit_code == 0 else "FAIL"
    if status == "failed":
        return "FAIL"
    return "SKIPPED"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Aggregate per-repo result.json files from a federated-fan-out run."
    )
    parser.add_argument("--run-id", required=True, dest="run_id", help="Run identifier")
    args = parser.parse_args()

    workspace = WORKSPACE_ROOT / args.run_id
    if not workspace.is_dir():
        print(
            f"error: workspace ~/.forge-cross-repo/{args.run_id}/ does not exist",
            file=sys.stderr,
        )
        return 1

    # Collect per-repo results
    repo_dirs = sorted(
        d for d in workspace.iterdir()
        if d.is_dir() and (d / "result.json").exists()
    )

    entries = []
    # Track summary hash → cluster label
    cluster_map: dict[str, str] = {}
    cluster_counter = [0]

    def get_cluster(summary: str) -> str:
        h = sha256_short(summary)
        if h not in cluster_map:
            cluster_counter[0] += 1
            cluster_map[h] = f"c{cluster_counter[0]}"
        return cluster_map[h]

    for repo_dir in repo_dirs:
        result_path = repo_dir / "result.json"
        try:
            result = json.loads(result_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as e:
            result = {"status": "failed", "summary": f"unreadable result.json: {e}"}

        verdict = verdict_for(result)
        summary = result.get("summary", "(no summary)")
        cluster_id = get_cluster(summary)

        entries.append({
            "repo": repo_dir.name,
            "verdict": verdict,
            "summary": summary,
            "summary_cluster_id": cluster_id,
        })

    # Also collect dirs that exist but have no result.json (SKIPPED)
    all_subdirs = sorted(d for d in workspace.iterdir() if d.is_dir())
    result_names = {e["repo"] for e in entries}
    for d in all_subdirs:
        if d.name not in result_names:
            entries.append({
                "repo": d.name,
                "verdict": "SKIPPED",
                "summary": "no result.json",
                "summary_cluster_id": get_cluster("no result.json"),
            })

    # Write aggregated.json
    aggregated = {"run_id": args.run_id, "repos": entries}
    agg_path = workspace / "aggregated.json"
    with open(agg_path, "w", encoding="utf-8") as f:
        json.dump(aggregated, f, indent=2)
        f.write("\n")

    # Append ledger entry
    ledger_path = workspace / "ledger.jsonl"
    with open(ledger_path, "a", encoding="utf-8") as f:
        f.write(json.dumps({
            "event": "aggregate_complete",
            "ts": ts(),
            "run_id": args.run_id,
            "repos_count": len(entries),
            "clusters": len(cluster_map),
        }) + "\n")

    # Print verdict matrix
    print(f"{'repo':<20}  {'verdict':<8}  {'cluster':<8}  summary")
    print("-" * 68)
    for e in entries:
        print(f"{e['repo']:<20}  {e['verdict']:<8}  {e['summary_cluster_id']:<8}  {e['summary'][:40]}")

    print(f"\naggregated.json written: {agg_path}")
    print(f"repos: {len(entries)}  clusters: {len(cluster_map)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
