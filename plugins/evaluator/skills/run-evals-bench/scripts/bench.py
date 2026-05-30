#!/usr/bin/env python3
"""bench.py — comparative skill benchmark (with-skill vs without-skill).

Args:
  --skill <name|path>   Skill directory name or full path.
  --iterations N        Number of runs per config (default 3).
  --baseline {none,prev} Compare against prior run (default none).
  --out <dir>           Workspace output directory.
  --mock                Synthetic mode: skip real claude -p calls (dev/CI).
  --help                Show this message.

Exit codes:
  0  completed (may have WARN lines for no-signal assertions)
  1  error (missing evals.json, bad args, sub-process failure)
  2  input/schema error
"""

import argparse
import json
import math
import os
import subprocess
import sys
import time
import tempfile
from pathlib import Path


def find_skill_dir(skill_arg: str) -> Path:
    """Resolve skill name or path to a directory that contains evals/evals.json."""
    p = Path(skill_arg)
    if p.exists():
        return p

    # Search plugins/*/skills/<name>
    repo_root = Path(__file__).resolve().parents[5]
    candidates = list(repo_root.glob(f"plugins/*/skills/{skill_arg}"))
    if len(candidates) == 1:
        return candidates[0]
    if len(candidates) > 1:
        print(f"ERROR: ambiguous skill '{skill_arg}': {candidates}", file=sys.stderr)
        sys.exit(1)

    print(f"ERROR: skill '{skill_arg}' not found", file=sys.stderr)
    sys.exit(1)


def load_evals(skill_dir: Path) -> dict:
    evals_path = skill_dir / "evals" / "evals.json"
    if not evals_path.exists():
        print(f"ERROR: evals.json not found at {evals_path}", file=sys.stderr)
        sys.exit(1)
    try:
        with open(evals_path) as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        print(f"ERROR: cannot parse evals.json: {e}", file=sys.stderr)
        sys.exit(2)


def run_claude(prompt: str, skill_dir: Path | None, mock: bool) -> tuple[str, dict]:
    """Run claude -p with optional --add-dir injection. Returns (output, timing)."""
    if mock:
        config = "with_skill" if skill_dir else "without_skill"
        output = f"[mock output] config={config} prompt={prompt[:40]}"
        timing = {"total_tokens": 42, "duration_ms": 10}
        return output, timing

    cmd = ["claude", "-p", "--no-color"]
    if skill_dir:
        cmd += ["--add-dir", str(skill_dir)]
    cmd.append(prompt)

    start = time.time()
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,
        )
        duration_ms = int((time.time() - start) * 1000)
        output = result.stdout or result.stderr or ""
        # Estimate tokens: rough 4-chars-per-token heuristic when not provided.
        total_tokens = len(output) // 4
        timing = {"total_tokens": total_tokens, "duration_ms": duration_ms}
        return output, timing
    except subprocess.TimeoutExpired:
        print("ERROR: claude -p timed out after 120s", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError:
        print("ERROR: 'claude' binary not found in PATH", file=sys.stderr)
        sys.exit(1)


def grade_assertions(assertions: list[str], output: str, mock: bool) -> dict:
    """Produce grading.json content by checking each assertion against output."""
    results = []
    for assertion in assertions:
        if mock:
            # In mock mode, assertions pass when the output contains "mock output".
            passed = "mock output" in output
            evidence = "[mock output] config=" if passed else ""
        else:
            # Simple substring/keyword heuristic — real deployments would call an LLM judge.
            # Evidence must be a quoted output substring.
            keywords = assertion.lower().split()[:3]
            evidence = ""
            passed = False
            for kw in keywords:
                if kw in output.lower():
                    # Find the actual substring in the output (case-insensitive).
                    idx = output.lower().find(kw)
                    snip_start = max(0, idx - 10)
                    snip_end = min(len(output), idx + len(kw) + 30)
                    evidence = output[snip_start:snip_end]
                    passed = True
                    break

        results.append({
            "text": assertion,
            "passed": passed,
            "evidence": evidence,
        })

    passed_count = sum(1 for r in results if r["passed"])
    total = len(results)
    return {
        "assertions": results,
        "summary": {
            "passed": passed_count,
            "failed": total - passed_count,
            "total": total,
            "pass_rate": passed_count / total if total > 0 else 0.0,
        },
    }


def run_iteration(
    iteration: int,
    eval_cases: list[dict],
    skill_dir: Path,
    out_dir: Path,
    mock: bool,
) -> dict:
    """Run one full iteration (all eval cases, both configs). Returns benchmark dict."""
    iter_dir = out_dir / f"iteration-{iteration}"
    iter_dir.mkdir(parents=True, exist_ok=True)

    all_with: list[dict] = []
    all_without: list[dict] = []

    for case in eval_cases:
        case_id = case.get("id", "unknown")
        prompt = case.get("prompt", "")
        assertions = case.get("assertions", [])
        eval_name = f"eval-{case_id}"

        for config, inject in [("with_skill", skill_dir), ("without_skill", None)]:
            config_dir = iter_dir / eval_name / config
            outputs_dir = config_dir / "outputs"
            outputs_dir.mkdir(parents=True, exist_ok=True)

            output, timing = run_claude(prompt, inject, mock)

            # Write raw output.
            (outputs_dir / "response.txt").write_text(output)

            # Write timing.
            (config_dir / "timing.json").write_text(json.dumps(timing, indent=2))

            # Grade assertions.
            grading = grade_assertions(assertions, output, mock)
            (config_dir / "grading.json").write_text(json.dumps(grading, indent=2))

            if config == "with_skill":
                all_with.append(grading["summary"])
            else:
                all_without.append(grading["summary"])

    # Aggregate across all eval cases.
    def aggregate(summaries: list[dict]) -> dict:
        if not summaries:
            return {"pass_rate": 0.0, "time_seconds": 0.0, "tokens": 0, "mean": 0.0, "stddev": 0.0}
        rates = [s["pass_rate"] for s in summaries]
        mean = sum(rates) / len(rates)
        variance = sum((r - mean) ** 2 for r in rates) / len(rates) if len(rates) > 1 else 0.0
        return {
            "pass_rate": mean,
            "time_seconds": 0.0,   # populated below from timing files
            "tokens": 0,
            "mean": mean,
            "stddev": math.sqrt(variance),
        }

    with_agg = aggregate(all_with)
    without_agg = aggregate(all_without)

    # Collect timing totals across eval cases.
    for config, agg in [("with_skill", with_agg), ("without_skill", without_agg)]:
        total_ms = 0
        total_tok = 0
        for case in eval_cases:
            timing_path = iter_dir / f"eval-{case.get('id','unknown')}" / config / "timing.json"
            if timing_path.exists():
                t = json.loads(timing_path.read_text())
                total_ms += t.get("duration_ms", 0)
                total_tok += t.get("total_tokens", 0)
        agg["time_seconds"] = total_ms / 1000.0
        agg["tokens"] = total_tok

    benchmark = {
        "skill": skill_dir.name,
        "iteration": iteration,
        "with_skill": with_agg,
        "without_skill": without_agg,
        "delta": {
            "pass_rate": with_agg["pass_rate"] - without_agg["pass_rate"],
            "time_seconds": with_agg["time_seconds"] - without_agg["time_seconds"],
            "tokens": with_agg["tokens"] - without_agg["tokens"],
        },
    }
    (iter_dir / "benchmark.json").write_text(json.dumps(benchmark, indent=2))

    # Warn on no-signal assertions (pass in both configs for every eval case).
    for case in eval_cases:
        for i, assertion in enumerate(case.get("assertions", [])):
            with_grading_path = iter_dir / f"eval-{case.get('id','unknown')}" / "with_skill" / "grading.json"
            without_grading_path = iter_dir / f"eval-{case.get('id','unknown')}" / "without_skill" / "grading.json"
            if with_grading_path.exists() and without_grading_path.exists():
                wg = json.loads(with_grading_path.read_text())
                wog = json.loads(without_grading_path.read_text())
                with_entries = wg.get("assertions", [])
                without_entries = wog.get("assertions", [])
                if i < len(with_entries) and i < len(without_entries):
                    if with_entries[i]["passed"] and without_entries[i]["passed"]:
                        print(
                            f"WARN: assertion '{assertion}' has no signal (passes in both configs)",
                            file=sys.stderr,
                        )

    return benchmark


def main():
    parser = argparse.ArgumentParser(
        description="Comparative skill benchmark: with-skill vs without-skill.",
        epilog="Exit 0 = done; exit 1 = error or no-signal assertions present.",
    )
    parser.add_argument("--skill", required=True, help="Skill name or path")
    parser.add_argument("--iterations", type=int, default=3, help="Runs per config (default 3)")
    parser.add_argument("--baseline", choices=["none", "prev"], default="none",
                        help="Baseline mode (default none)")
    parser.add_argument("--out", default=None, help="Output workspace directory")
    parser.add_argument("--mock", action="store_true",
                        help="Synthetic mode: skip real claude -p calls (dev/CI only)")
    args = parser.parse_args()

    if args.iterations < 1:
        print("ERROR: --iterations must be ≥ 1", file=sys.stderr)
        sys.exit(1)

    skill_dir = find_skill_dir(args.skill)

    evals_data = load_evals(skill_dir)
    eval_cases = evals_data.get("evals", [])
    if not eval_cases:
        print("ERROR: evals.json has no eval cases", file=sys.stderr)
        sys.exit(1)

    if args.out:
        out_dir = Path(args.out)
    else:
        ts = int(time.time())
        out_dir = Path(tempfile.gettempdir()) / f"{skill_dir.name}-bench-{ts}"
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"bench: skill={skill_dir.name} iterations={args.iterations} out={out_dir} mock={args.mock}",
          file=sys.stderr)

    for i in range(1, args.iterations + 1):
        print(f"bench: running iteration {i}/{args.iterations}", file=sys.stderr)
        benchmark = run_iteration(i, eval_cases, skill_dir, out_dir, args.mock)
        print(
            f"bench: iteration {i} done — "
            f"with_skill.pass_rate={benchmark['with_skill']['pass_rate']:.2f} "
            f"delta={benchmark['delta']['pass_rate']:+.2f}",
            file=sys.stderr,
        )

    print(f"bench: complete. results in {out_dir}", file=sys.stderr)
    sys.exit(0)


if __name__ == "__main__":
    main()
