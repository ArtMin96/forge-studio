#!/usr/bin/env python3
"""Federated fan-out: spawn one subagent per repo with a shared prompt.

Usage:
  python3 run.py --repos <repos-file> --prompt <prompt-file> --run-id <id> [--mock]

--repos    File containing one absolute repo path per line (max 5).
--prompt   File containing the prompt/shell snippet passed to each subagent.
--run-id   Unique identifier for this run; workspace written to
           ~/.forge-cross-repo/<run-id>/.
--mock     Skip real claude -p invocations; write deterministic result.json
           (status: complete, summary: "mock"). Use for testing.
"""

import argparse
import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


WORKSPACE_ROOT = Path.home() / ".forge-cross-repo"
MAX_REPOS = 5
STDOUT_TAIL_LINES = 50


def ts() -> str:
    return datetime.now(timezone.utc).isoformat()


def append_ledger(ledger_path: Path, entry: dict) -> None:
    with open(ledger_path, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry) + "\n")


def write_result(result_path: Path, data: dict) -> None:
    result_path.parent.mkdir(parents=True, exist_ok=True)
    with open(result_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def tail(text: str, n: int = STDOUT_TAIL_LINES) -> str:
    lines = text.splitlines()
    return "\n".join(lines[-n:]) if lines else ""


def run_repo(repo: Path, prompt_text: str, run_id: str, workspace: Path, mock: bool) -> dict:
    repo_name = repo.name
    result_path = workspace / repo_name / "result.json"
    ledger_path = workspace / "ledger.jsonl"

    append_ledger(ledger_path, {
        "event": "start",
        "ts": ts(),
        "repo": str(repo),
        "repo_basename": repo_name,
        "run_id": run_id,
    })

    if mock:
        result = {
            "status": "complete",
            "exit_code": 0,
            "stdout_tail": "mock output",
            "stderr_tail": "",
            "summary": "mock",
        }
        write_result(result_path, result)
        append_ledger(ledger_path, {
            "event": "complete",
            "ts": ts(),
            "repo": str(repo),
            "repo_basename": repo_name,
            "run_id": run_id,
        })
        return result

    if not repo.is_dir():
        result = {
            "status": "failed",
            "exit_code": -1,
            "stdout_tail": "",
            "stderr_tail": f"repo path does not exist: {repo}",
            "summary": f"failed: repo path does not exist: {repo}",
        }
        write_result(result_path, result)
        append_ledger(ledger_path, {
            "event": "failed",
            "ts": ts(),
            "repo": str(repo),
            "repo_basename": repo_name,
            "run_id": run_id,
            "detail": result["stderr_tail"],
        })
        return result

    try:
        proc = subprocess.run(
            ["claude", "-p", "--add-dir", str(repo), prompt_text],
            cwd=str(repo),
            capture_output=True,
            text=True,
            timeout=600,
        )
        stdout_tail = tail(proc.stdout)
        stderr_tail = tail(proc.stderr)
        status = "complete" if proc.returncode == 0 else "failed"
        result = {
            "status": status,
            "exit_code": proc.returncode,
            "stdout_tail": stdout_tail,
            "stderr_tail": stderr_tail,
            "summary": stdout_tail[:200] if stdout_tail else "(no output)",
        }
        event = "complete" if status == "complete" else "failed"
    except subprocess.TimeoutExpired:
        result = {
            "status": "failed",
            "exit_code": -1,
            "stdout_tail": "",
            "stderr_tail": "timed out after 600s",
            "summary": "failed: timeout",
        }
        event = "failed"
    except FileNotFoundError:
        result = {
            "status": "failed",
            "exit_code": -1,
            "stdout_tail": "",
            "stderr_tail": "claude CLI not found on PATH",
            "summary": "failed: claude CLI not found",
        }
        event = "failed"

    write_result(result_path, result)
    append_ledger(ledger_path, {
        "event": event,
        "ts": ts(),
        "repo": str(repo),
        "repo_basename": repo.name,
        "run_id": run_id,
        "detail": result.get("stderr_tail", "")[:200],
    })
    return result


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Federated fan-out: apply a shared prompt to ≤5 sibling repos via subagents."
    )
    parser.add_argument("--repos", required=True, help="File with one absolute repo path per line (max 5)")
    parser.add_argument("--prompt", required=True, help="File containing the prompt passed to each subagent")
    parser.add_argument("--run-id", required=True, dest="run_id", help="Unique run identifier")
    parser.add_argument("--mock", action="store_true", help="Skip real subagents; write deterministic results")
    args = parser.parse_args()

    repos_file = Path(args.repos)
    prompt_file = Path(args.prompt)

    if not repos_file.exists():
        print(f"error: repos-file not found: {repos_file}", file=sys.stderr)
        return 1

    if not prompt_file.exists():
        print(f"error: prompt-file not found: {prompt_file}", file=sys.stderr)
        return 1

    repos_lines = [l.strip() for l in repos_file.read_text().splitlines() if l.strip()]
    if len(repos_lines) > MAX_REPOS:
        print(
            f"error: repos-file has {len(repos_lines)} entries; max is {MAX_REPOS} (Anthropic batch limit)",
            file=sys.stderr,
        )
        return 1

    if len(repos_lines) == 0:
        print("error: repos-file is empty", file=sys.stderr)
        return 1

    prompt_text = prompt_file.read_text()

    workspace = WORKSPACE_ROOT / args.run_id
    workspace.mkdir(parents=True, exist_ok=True)

    print(f"run-id: {args.run_id}")
    print(f"workspace: {workspace}")
    print(f"repos ({len(repos_lines)}):")
    for r in repos_lines:
        print(f"  {r}")
    print()

    results = {}
    for repo_str in repos_lines:
        repo = Path(repo_str)
        print(f"  -> {repo.name} ...", end=" ", flush=True)
        result = run_repo(repo, prompt_text, args.run_id, workspace, args.mock)
        results[repo.name] = result
        print(result["status"])

    print()
    print(f"{'repo':<20}  {'status':<10}  summary")
    print("-" * 60)
    for name, r in results.items():
        print(f"{name:<20}  {r['status']:<10}  {r['summary'][:40]}")

    ledger_path = workspace / "ledger.jsonl"
    if ledger_path.exists():
        lines = ledger_path.read_text().strip().splitlines()
        print(f"\nledger: {len(lines)} entries in {ledger_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
