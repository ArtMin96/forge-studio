#!/usr/bin/env python3
"""optimize.py — iterative description optimization loop.

Splits a query corpus 60/40 train/val (by seed), runs trigger-rate probes
each iteration, refines the skill description, and picks the best revision
by validation pass rate (not the last iteration — overfitting guard).

Args:
  --skill <path>        Path to skill directory (contains SKILL.md).
  --corpus <file>       JSON corpus: {positive: [str>=8], negative: [str>=8]}.
  --iterations N        Optimization iterations (default 5).
  --seed S              RNG seed for reproducible 60/40 split (default 0).
  --mock                Synthetic mode: skip real claude -p calls (dev/CI).
  --out <dir>           Output workspace directory.
  --help                Show this message.

Exit codes:
  0  success — result.json written
  1  corpus validation failure or runtime error
  2  input/schema error
"""

import argparse
import json
import os
import random
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def load_corpus(corpus_path: str) -> dict:
    try:
        with open(corpus_path) as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"ERROR: cannot read corpus: {e}", file=sys.stderr)
        sys.exit(2)

    positives = data.get("positive", [])
    negatives = data.get("negative", [])

    if len(positives) < 8 or len(negatives) < 8:
        print(
            "corpus must have ≥8 positive and ≥8 negative queries",
            file=sys.stderr,
        )
        sys.exit(1)

    return {"positive": positives, "negative": negatives}


def split_corpus(corpus: dict, seed: int) -> tuple[dict, dict]:
    """Split corpus 60/40 into train/val deterministically by seed."""
    rng = random.Random(seed)

    def split_list(items: list) -> tuple[list, list]:
        shuffled = list(items)
        rng.shuffle(shuffled)
        cut = max(1, int(len(shuffled) * 0.6))
        return shuffled[:cut], shuffled[cut:]

    pos_train, pos_val = split_list(corpus["positive"])
    neg_train, neg_val = split_list(corpus["negative"])

    train = {"positive": pos_train, "negative": neg_train}
    val = {"positive": pos_val, "negative": neg_val}
    return train, val


def read_current_description(skill_dir: Path) -> str:
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        print(f"ERROR: SKILL.md not found at {skill_md}", file=sys.stderr)
        sys.exit(1)

    content = skill_md.read_text()
    m = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    if not m:
        print(f"ERROR: no YAML frontmatter in {skill_md}", file=sys.stderr)
        sys.exit(2)

    import yaml
    try:
        fm = yaml.safe_load(m.group(1)) or {}
    except Exception as e:
        print(f"ERROR: YAML parse error in {skill_md}: {e}", file=sys.stderr)
        sys.exit(2)

    desc = fm.get("description", "")
    if not desc:
        print(f"ERROR: no description field in {skill_md}", file=sys.stderr)
        sys.exit(1)
    return desc


def probe_trigger(query: str, description: str, skill_name: str, mock: bool) -> bool:
    """Ask Claude whether this skill should trigger on the query. Returns True/False."""
    if mock:
        # Deterministic mock: positive queries (shorter) trigger, longer ones don't.
        # This gives iteration 1 a slight edge to test the best-iteration selection.
        return len(query) < 20

    prompt = (
        f'Should the Claude Code skill named "{skill_name}" '
        f'(description: "{description}") '
        f'trigger on this user query? Reply with exactly one word: yes or no.\n\n'
        f'Query: {query}'
    )
    try:
        result = subprocess.run(
            ["claude", "-p", "--no-color", prompt],
            capture_output=True,
            text=True,
            timeout=60,
        )
        out = (result.stdout or "").strip().lower()
        return out.startswith("yes")
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def compute_pass_rate(
    queries: dict,
    description: str,
    skill_name: str,
    mock: bool,
    runs: int = 3,
) -> tuple[float, list[str], list[str]]:
    """Compute trigger-rate pass rate across positive/negative queries.

    Returns (pass_rate, false_negatives, false_positives).
    A positive query passes when trigger_rate >= 0.5 (should trigger).
    A negative query passes when trigger_rate < 0.5 (should not trigger).
    """
    false_negatives: list[str] = []
    false_positives: list[str] = []
    passed = 0
    total = 0

    for query in queries["positive"]:
        triggers = sum(probe_trigger(query, description, skill_name, mock) for _ in range(runs))
        rate = triggers / runs
        total += 1
        if rate >= 0.5:
            passed += 1
        else:
            false_negatives.append(query)

    for query in queries["negative"]:
        triggers = sum(probe_trigger(query, description, skill_name, mock) for _ in range(runs))
        rate = triggers / runs
        total += 1
        if rate < 0.5:
            passed += 1
        else:
            false_positives.append(query)

    pass_rate = passed / total if total > 0 else 0.0
    return pass_rate, false_negatives, false_positives


def revise_description(
    current_description: str,
    skill_name: str,
    false_negatives: list[str],
    false_positives: list[str],
    mock: bool,
) -> str:
    """Generate one revised description via sub-Claude call with failure hints."""
    if mock:
        # Synthetic revision: append a minor variation to simulate improvement.
        return current_description.rstrip(".") + ". Handles edge cases precisely."

    hints = []
    if false_negatives:
        samples = "; ".join(false_negatives[:3])
        hints.append(f"broaden so these queries trigger it: {samples}")
    if false_positives:
        samples = "; ".join(false_positives[:3])
        hints.append(f"narrow/disambiguate so these queries do NOT trigger it: {samples}")

    if not hints:
        return current_description

    hint_text = " | ".join(hints)
    prompt = (
        f'Rewrite this Claude Code skill description to fix trigger-rate failures.\n\n'
        f'Skill name: {skill_name}\n'
        f'Current description: {current_description}\n\n'
        f'Fix hints: {hint_text}\n\n'
        f'Rules:\n'
        f'- Do not copy keywords verbatim from the failed queries.\n'
        f'- Keep the description to one or two sentences.\n'
        f'- Preserve the core purpose of the skill.\n\n'
        f'Output only the new description text, nothing else.'
    )

    try:
        result = subprocess.run(
            ["claude", "-p", "--no-color", prompt],
            capture_output=True,
            text=True,
            timeout=60,
        )
        revised = (result.stdout or "").strip()
        return revised if revised else current_description
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return current_description


def main():
    parser = argparse.ArgumentParser(
        description="Iterative description optimization loop.",
        epilog="Exit 0 = result.json written; exit 1 = corpus/runtime error; exit 2 = schema error.",
    )
    parser.add_argument("--skill", required=True, help="Path to skill directory")
    parser.add_argument("--corpus", required=True, help="Path to corpus JSON")
    parser.add_argument("--iterations", type=int, default=5, help="Optimization iterations (default 5)")
    parser.add_argument("--seed", type=int, default=0, help="RNG seed for 60/40 split (default 0)")
    parser.add_argument("--mock", action="store_true",
                        help="Synthetic mode: skip real claude -p calls (dev/CI only)")
    parser.add_argument("--out", default=None, help="Output workspace directory")
    args = parser.parse_args()

    if args.iterations < 1:
        print("ERROR: --iterations must be >= 1", file=sys.stderr)
        sys.exit(1)

    skill_dir = Path(args.skill)
    if not skill_dir.exists():
        print(f"ERROR: skill directory not found: {skill_dir}", file=sys.stderr)
        sys.exit(1)

    corpus = load_corpus(args.corpus)
    train, val = split_corpus(corpus, args.seed)

    skill_name = skill_dir.name
    initial_description = read_current_description(skill_dir)

    if args.out:
        out_dir = Path(args.out)
    else:
        ts = int(time.time())
        out_dir = Path(tempfile.gettempdir()) / f"{skill_name}-optimize-{ts}"
    out_dir.mkdir(parents=True, exist_ok=True)

    print(
        f"optimize: skill={skill_name} iterations={args.iterations} "
        f"seed={args.seed} mock={args.mock} out={out_dir}",
        file=sys.stderr,
    )
    print(
        f"optimize: corpus positive={len(corpus['positive'])} negative={len(corpus['negative'])} "
        f"train_pos={len(train['positive'])} val_pos={len(val['positive'])}",
        file=sys.stderr,
    )

    # Measure baseline val pass rate with the current description.
    baseline_val_rate, _, _ = compute_pass_rate(val, initial_description, skill_name, args.mock)
    print(f"optimize: baseline val_pass_rate={baseline_val_rate:.3f}", file=sys.stderr)

    current_description = initial_description
    best_val_rate = -1.0
    best_iteration = 1
    best_description = current_description

    for i in range(1, args.iterations + 1):
        iter_dir = out_dir / f"iteration-{i}"
        iter_dir.mkdir(parents=True, exist_ok=True)

        print(f"optimize: iteration {i}/{args.iterations}", file=sys.stderr)

        # Evaluate on train set to find failures.
        train_rate, fn, fp = compute_pass_rate(train, current_description, skill_name, args.mock)
        # Evaluate on val set to pick the best iteration.
        val_rate, _, _ = compute_pass_rate(val, current_description, skill_name, args.mock)

        print(
            f"optimize: iteration {i} train={train_rate:.3f} val={val_rate:.3f} "
            f"fn={len(fn)} fp={len(fp)}",
            file=sys.stderr,
        )

        # Write per-iteration artifacts.
        (iter_dir / "description.txt").write_text(current_description)
        (iter_dir / "train_failures.json").write_text(
            json.dumps({"false_negatives": fn, "false_positives": fp}, indent=2)
        )
        (iter_dir / "val_pass_rate.json").write_text(
            json.dumps({"val_pass_rate": val_rate, "train_pass_rate": train_rate}, indent=2)
        )

        # Track best by val pass rate (first iteration wins on tie — conservative choice).
        if val_rate > best_val_rate:
            best_val_rate = val_rate
            best_iteration = i
            best_description = current_description

        # Generate revised description for the next iteration (skip on last).
        if i < args.iterations:
            current_description = revise_description(
                current_description, skill_name, fn, fp, args.mock
            )

    result = {
        "best_iteration": best_iteration,
        "best_val_pass_rate": best_val_rate,
        "current_val_pass_rate": baseline_val_rate,
        "proposed_description": best_description,
        "sanity_check_required": best_val_rate < 0.80,
    }
    result_path = out_dir / "result.json"
    result_path.write_text(json.dumps(result, indent=2))

    print(
        f"optimize: done — best_iteration={best_iteration} "
        f"best_val_pass_rate={best_val_rate:.3f} "
        f"sanity_check_required={result['sanity_check_required']}",
        file=sys.stderr,
    )
    print(f"optimize: result written to {result_path}", file=sys.stderr)
    sys.exit(0)


if __name__ == "__main__":
    main()
