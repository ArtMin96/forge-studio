#!/usr/bin/env python3
"""pareto-best.py — pick the lex-best candidate from a Pareto frontier.

Argv: one or more paths to JSON files, each containing:
  {"candidate_id": "<str>", "pass_rate": <float>, "token_cost": <int>}

Outputs the Pareto-best candidate as a single JSON line on stdout.

Pareto dominance rule:
  a dominates b  iff  a.pass_rate >= b.pass_rate
                  AND  a.token_cost <= b.token_cost
                  AND  (a.pass_rate > b.pass_rate OR a.token_cost < b.token_cost)

Lex-best from the non-dominated set:
  max pass_rate; tie-break by min token_cost.
"""

import json
import sys


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: pareto-best.py <json-file> [<json-file> ...]", file=sys.stderr)
        sys.exit(1)

    candidates = []
    for path in sys.argv[1:]:
        try:
            with open(path) as f:
                data = json.load(f)
            # Normalise types defensively.
            candidates.append({
                "candidate_id": str(data["candidate_id"]),
                "pass_rate": float(data["pass_rate"]),
                "token_cost": int(data["token_cost"]),
            })
        except (KeyError, ValueError, OSError) as exc:
            print(f"WARN: skipping {path}: {exc}", file=sys.stderr)

    if not candidates:
        print("Error: no valid candidates found", file=sys.stderr)
        sys.exit(1)

    # Compute Pareto frontier (non-dominated set).
    def dominates(a: dict, b: dict) -> bool:
        """Return True if a dominates b."""
        return (
            a["pass_rate"] >= b["pass_rate"]
            and a["token_cost"] <= b["token_cost"]
            and (a["pass_rate"] > b["pass_rate"] or a["token_cost"] < b["token_cost"])
        )

    non_dominated = []
    for candidate in candidates:
        if not any(dominates(other, candidate) for other in candidates if other is not candidate):
            non_dominated.append(candidate)

    # Lex-best: highest pass_rate, tie-break by lowest token_cost.
    best = min(
        non_dominated,
        key=lambda c: (-c["pass_rate"], c["token_cost"]),
    )

    print(json.dumps(best))


if __name__ == "__main__":
    main()
