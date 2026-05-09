#!/usr/bin/env python3
import json
import sys
import argparse


def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"INPUT_ERROR: cannot read {path}: {e}", file=sys.stderr)
        sys.exit(2)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("rubric", help="Path to rubric JSON")
    parser.add_argument("scores", help="Path to criterion-scores JSON")
    parser.add_argument("--variant", choices=["control", "treatment"], default=None)
    args = parser.parse_args()

    rubric = load_json(args.rubric)
    raw_scores = load_json(args.scores)

    criteria = rubric.get("criteria")
    if not criteria or not isinstance(criteria, list):
        print("INPUT_ERROR: rubric missing criteria array", file=sys.stderr)
        sys.exit(2)

    weight_sum = sum(c.get("weight", 0) for c in criteria)
    if abs(weight_sum - 1.0) >= 1e-6:
        print(f"WEIGHT_SUM_FAIL: {weight_sum}", file=sys.stderr)
        sys.exit(1)

    per_criterion = []
    total_score = 0.0

    for c in criteria:
        cid = c.get("id")
        if cid is None:
            print("INPUT_ERROR: criterion missing id", file=sys.stderr)
            sys.exit(2)
        if cid not in raw_scores:
            print(f"INPUT_ERROR: missing criterion id '{cid}' in scores file", file=sys.stderr)
            sys.exit(2)

        raw = raw_scores[cid]
        weight = c.get("weight", 0)
        ctype = c.get("type")

        if ctype == "scored":
            scale = c.get("scale", {})
            lo = scale.get("min", 0)
            hi = scale.get("max", 1)
            # clamp to scale
            raw_clamped = max(lo, min(hi, raw))
            if hi == lo:
                weighted = 0.0
            else:
                weighted = (raw_clamped - lo) / (hi - lo) * weight
        elif ctype in ("binary", "reference-based"):
            if raw not in (0, 1):
                print(f"INPUT_ERROR: criterion '{cid}' type '{ctype}' expects 0 or 1, got {raw}", file=sys.stderr)
                sys.exit(2)
            weighted = raw * weight
        else:
            print(f"INPUT_ERROR: criterion '{cid}' has unknown type '{ctype}'", file=sys.stderr)
            sys.exit(2)

        total_score += weighted
        per_criterion.append({"id": cid, "raw": raw, "weighted": weighted})

    result = {
        "rubricId": rubric.get("name", ""),
        "rubricVersion": rubric.get("version", ""),
        "score": total_score,
        "perCriterion": per_criterion,
        "variantLabel": args.variant,
        "winner": None,
        "delta": None,
        "confidence": None,
        "pValue": None,
    }

    print(json.dumps(result, indent=2))
    sys.exit(0)


if __name__ == "__main__":
    main()
