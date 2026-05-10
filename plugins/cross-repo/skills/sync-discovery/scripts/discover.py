#!/usr/bin/env python3
"""sync-discovery: find a regex pattern in two repos and classify matches.

Usage:
  python3 discover.py --repo-a <path> --repo-b <path> --pattern <regex> --out <file>

--repo-a    Absolute path to the first git repository.
--repo-b    Absolute path to the second git repository.
--pattern   Extended regex passed to git grep -nE.
--out       Path to write discovery.json.

Output schema (discovery.json):
  {
    "only_in_a": [{"file": str, "line": int, "hash": str}],
    "only_in_b": [{"file": str, "line": int, "hash": str}],
    "in_both": [{"file_a": str, "file_b": str, "hash_a": str, "hash_b": str, "divergent": bool}]
  }
"""

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path


def sha256_of(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def git_grep(repo: Path, pattern: str) -> list[dict]:
    """Run git grep -nE in repo; return list of {file, line, content, hash}."""
    try:
        result = subprocess.run(
            ["git", "-C", str(repo), "grep", "-nE", "--", pattern],
            capture_output=True,
            text=True,
            timeout=60,
        )
    except FileNotFoundError:
        print(f"error: git not found on PATH", file=sys.stderr)
        sys.exit(1)
    except subprocess.TimeoutExpired:
        print(f"error: git grep timed out in {repo}", file=sys.stderr)
        sys.exit(1)

    # Exit code 1 from git grep means "no matches" — that's fine.
    if result.returncode not in (0, 1):
        print(
            f"error: git grep failed in {repo} (exit {result.returncode}): {result.stderr.strip()}",
            file=sys.stderr,
        )
        sys.exit(1)

    matches = []
    for raw_line in result.stdout.splitlines():
        # Format: <file>:<lineno>:<content>
        parts = raw_line.split(":", 2)
        if len(parts) < 3:
            continue
        file_path, lineno_str, content = parts[0], parts[1], parts[2]
        try:
            lineno = int(lineno_str)
        except ValueError:
            continue
        matches.append({
            "file": file_path,
            "line": lineno,
            "content": content,
            "hash": sha256_of(content),
        })
    return matches


def classify(matches_a: list[dict], matches_b: list[dict]) -> dict:
    """Classify matches into only_in_a, only_in_b, in_both by content hash."""
    # Build hash → list-of-match mappings
    hashes_a: dict[str, list[dict]] = {}
    for m in matches_a:
        hashes_a.setdefault(m["hash"], []).append(m)

    hashes_b: dict[str, list[dict]] = {}
    for m in matches_b:
        hashes_b.setdefault(m["hash"], []).append(m)

    only_in_a = []
    only_in_b = []
    in_both = []

    all_hashes = set(hashes_a) | set(hashes_b)
    for h in sorted(all_hashes):
        in_a = hashes_a.get(h, [])
        in_b = hashes_b.get(h, [])
        if in_a and not in_b:
            for m in in_a:
                only_in_a.append({"file": m["file"], "line": m["line"], "hash": m["hash"]})
        elif in_b and not in_a:
            for m in in_b:
                only_in_b.append({"file": m["file"], "line": m["line"], "hash": m["hash"]})
        else:
            # present in both — pair them up (zip; extras go to the longer side)
            for ma, mb in zip(in_a, in_b):
                in_both.append({
                    "file_a": ma["file"],
                    "file_b": mb["file"],
                    "hash_a": ma["hash"],
                    "hash_b": mb["hash"],
                    "divergent": ma["hash"] != mb["hash"],
                })
            # Remaining unpaired items from the longer list
            for ma in in_a[len(in_b):]:
                only_in_a.append({"file": ma["file"], "line": ma["line"], "hash": ma["hash"]})
            for mb in in_b[len(in_a):]:
                only_in_b.append({"file": mb["file"], "line": mb["line"], "hash": mb["hash"]})

    return {"only_in_a": only_in_a, "only_in_b": only_in_b, "in_both": in_both}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Cross-repo pattern discovery using git grep."
    )
    parser.add_argument("--repo-a", required=True, help="Path to first git repository")
    parser.add_argument("--repo-b", required=True, help="Path to second git repository")
    parser.add_argument("--pattern", required=True, help="Extended regex pattern (git grep -nE)")
    parser.add_argument("--out", required=True, help="Output path for discovery.json")
    args = parser.parse_args()

    repo_a = Path(args.repo_a)
    repo_b = Path(args.repo_b)

    if not repo_a.is_dir():
        print(f"error: --repo-a path does not exist or is not a directory: {repo_a}", file=sys.stderr)
        return 1

    if not repo_b.is_dir():
        print(f"error: --repo-b path does not exist or is not a directory: {repo_b}", file=sys.stderr)
        return 1

    matches_a = git_grep(repo_a, args.pattern)
    matches_b = git_grep(repo_b, args.pattern)

    discovery = classify(matches_a, matches_b)

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(discovery, f, indent=2)
        f.write("\n")

    n_a = len(discovery["only_in_a"])
    n_b = len(discovery["only_in_b"])
    n_both = len(discovery["in_both"])
    print(f"only_in_a: {n_a}  only_in_b: {n_b}  in_both: {n_both}")
    print(f"written: {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
