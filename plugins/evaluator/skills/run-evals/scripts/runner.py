#!/usr/bin/env python3
"""Structural validator for per-skill eval JSON fixtures.

Usage: runner.py <path-to-evals.json-or-glob>

Validates that each matched file conforms to the evals/evals.json shape:
  {skill_name: str, evals: [{id: int, prompt: str, files: [...], assertions: [str, ...]}]}

Only accepts files named evals.json. Emits a human-readable checklist of
declared assertions, with [ ] boxes marking each as "not yet executed."

Exit codes:
  0 — all files valid
  1 — at least one file has a shape violation or wrong filename
  2 — JSON parse error on at least one file
"""
import glob as glob_module
import json
import os
import sys


def validate_file_item(item):
    """Return error string if a files[] item is malformed, else None."""
    if isinstance(item, str):
        return None
    if isinstance(item, dict):
        if 'path' not in item or not isinstance(item['path'], str):
            return "files[] object missing required string 'path'"
        if 'content' not in item or not isinstance(item['content'], str):
            return "files[] object missing required string 'content'"
        return None
    return f"files[] item must be a string or {{path, content}} object, got {type(item).__name__}"


def validate_eval_item(idx, item):
    """Validate one entry in the evals list. Returns list of error strings."""
    errors = []
    if not isinstance(item, dict):
        return [f"evals[{idx}] must be an object"]

    # id: int
    if 'id' not in item:
        errors.append(f"evals[{idx}]: missing required key 'id'")
    elif not isinstance(item['id'], int):
        errors.append(f"evals[{idx}]: 'id' must be an integer")

    # prompt: non-empty string
    if 'prompt' not in item:
        errors.append(f"evals[{idx}]: missing required key 'prompt'")
    elif not isinstance(item['prompt'], str) or item['prompt'].strip() == '':
        errors.append(f"evals[{idx}]: 'prompt' must be a non-empty string")

    # files: list (may be empty)
    if 'files' not in item:
        errors.append(f"evals[{idx}]: missing required key 'files'")
    elif not isinstance(item['files'], list):
        errors.append(f"evals[{idx}]: 'files' must be a list")
    else:
        for i, f in enumerate(item['files']):
            ferr = validate_file_item(f)
            if ferr:
                errors.append(f"evals[{idx}].files[{i}]: {ferr}")

    # assertions: non-empty list of strings
    if 'assertions' not in item:
        errors.append(f"evals[{idx}]: missing required key 'assertions'")
    elif not isinstance(item['assertions'], list) or len(item['assertions']) == 0:
        errors.append(f"evals[{idx}]: 'assertions' must be a non-empty list of strings")
    elif not all(isinstance(s, str) for s in item['assertions']):
        errors.append(f"evals[{idx}]: 'assertions' items must all be strings")

    # expected_output: optional str
    if 'expected_output' in item and not isinstance(item['expected_output'], str):
        errors.append(f"evals[{idx}]: 'expected_output' must be a string if present")

    return errors


def validate(path, data):
    """Validate shape of a parsed evals.json. Return list of error strings."""
    errors = []

    # Top-level required keys
    for key in ('skill_name', 'evals'):
        if key not in data:
            errors.append(f"missing required key '{key}'")

    if errors:
        return errors

    # skill_name: non-empty string
    if not isinstance(data['skill_name'], str) or data['skill_name'].strip() == '':
        errors.append("'skill_name' must be a non-empty string")

    # evals: non-empty list
    evals = data['evals']
    if not isinstance(evals, list) or len(evals) == 0:
        errors.append("'evals' must be a non-empty list")
    else:
        for idx, item in enumerate(evals):
            errors.extend(validate_eval_item(idx, item))

    return errors


def format_ok(path, data):
    """Return the human-readable OK report for a well-formed evals.json."""
    skill = data['skill_name']
    evals = data['evals']

    lines = [f"OK: {path}"]
    lines.append(f"  skill_name: {skill}")
    lines.append(f"  evals: {len(evals)} case(s)")
    for ev in evals:
        prompt = ev['prompt']
        truncated = prompt if len(prompt) <= 80 else prompt[:77] + '...'
        lines.append(f"  [{ev['id']}] {truncated}")
        lines.append(f"    files: {len(ev['files'])} declared")
        lines.append("    assertions:")
        for a in ev['assertions']:
            lines.append(f"      [ ] {a}")

    return '\n'.join(lines)


def resolve_paths(arg):
    """Return sorted list of file paths matched by arg (glob or literal)."""
    matched = sorted(glob_module.glob(arg))
    if not matched and not glob_module.has_magic(arg):
        # Literal path that doesn't exist — return it so caller can report
        return [arg]
    return matched


def main():
    if len(sys.argv) < 2:
        print("Usage: runner.py <path-to-evals.json-or-glob>", file=sys.stderr)
        sys.exit(2)

    arg = sys.argv[1]
    paths = resolve_paths(arg)

    ok_count = 0
    invalid_count = 0
    parse_error = False
    output_lines = []

    for path in paths:
        # Enforce evals.json filename convention
        basename = os.path.basename(path)
        if basename != 'evals.json':
            output_lines.append(f"INVALID: {path}: expected evals.json, got {basename}")
            invalid_count += 1
            continue

        # Parse JSON
        try:
            with open(path) as f:
                data = json.load(f)
        except FileNotFoundError:
            print(f"INPUT_ERROR: {path}: file not found", file=sys.stderr)
            parse_error = True
            continue
        except json.JSONDecodeError as e:
            print(f"INPUT_ERROR: {path}: {e}", file=sys.stderr)
            parse_error = True
            continue

        if not isinstance(data, dict):
            output_lines.append(f"INVALID: {path}: top-level value must be a JSON object")
            invalid_count += 1
            continue

        errors = validate(path, data)
        if errors:
            for err in errors:
                output_lines.append(f"INVALID: {path}: {err}")
            invalid_count += 1
        else:
            output_lines.append(format_ok(path, data))
            ok_count += 1

    total = ok_count + invalid_count
    for line in output_lines:
        print(line)
    print()
    print(f"{total} eval(s): {ok_count} OK, {invalid_count} INVALID")

    if parse_error:
        sys.exit(2)
    if invalid_count > 0:
        sys.exit(1)
    sys.exit(0)


if __name__ == '__main__':
    main()
