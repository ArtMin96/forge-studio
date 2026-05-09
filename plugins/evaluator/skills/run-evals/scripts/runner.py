#!/usr/bin/env python3
"""Structural validator for per-skill eval JSON fixtures.

Usage: runner.py <path-or-glob>

Validates that each matched file conforms to the evals/ convention shape:
  {skills: [str, ...], query: str, files: [...], expected_behavior: [str, ...]}

Does not execute the eval. Emits a human-readable checklist of declared
expectations, with [ ] boxes marking each as "not yet executed."

Exit codes:
  0 — all files valid
  1 — at least one file has a shape violation
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


def validate(path, data):
    """Validate shape of a parsed eval JSON. Return list of error strings."""
    errors = []

    # Check required keys
    for key in ('skills', 'query', 'files', 'expected_behavior'):
        if key not in data:
            errors.append(f"missing required key '{key}'")

    if errors:
        # Missing keys — stop here, remaining checks would be noisy
        return errors

    # skills: non-empty list of strings
    skills = data['skills']
    if not isinstance(skills, list) or len(skills) == 0:
        errors.append("'skills' must be a non-empty list of strings")
    elif not all(isinstance(s, str) for s in skills):
        errors.append("'skills' must be a non-empty list of strings")

    # query: non-empty string
    query = data['query']
    if not isinstance(query, str) or query.strip() == '':
        errors.append("'query' must be a non-empty string")

    # files: list (may be empty); each item is string or {path, content}
    files = data['files']
    if not isinstance(files, list):
        errors.append("'files' must be a list")
    else:
        for i, item in enumerate(files):
            item_err = validate_file_item(item)
            if item_err:
                errors.append(f"files[{i}]: {item_err}")

    # expected_behavior: non-empty list of strings
    eb = data['expected_behavior']
    if not isinstance(eb, list) or len(eb) == 0:
        errors.append("'expected_behavior' must be a non-empty list")
    elif not all(isinstance(s, str) for s in eb):
        errors.append("'expected_behavior' items must all be strings")

    return errors


def format_ok(path, data):
    """Return the human-readable OK report for a well-formed eval file."""
    skills_val = data['skills']
    query_val = data['query']
    files_val = data['files']
    eb_val = data['expected_behavior']

    lines = [f"OK: {path}"]
    lines.append(f"  skills: {', '.join(skills_val)}")

    truncated = query_val if len(query_val) <= 80 else query_val[:77] + '...'
    lines.append(f'  query: "{truncated}"')
    lines.append(f"  files: {len(files_val)} declared")
    lines.append("  expected_behavior:")
    for item in eb_val:
        lines.append(f"    [ ] {item}")

    return '\n'.join(lines)


def resolve_paths(arg):
    """Return sorted list of file paths matched by arg (glob or literal)."""
    matched = sorted(glob_module.glob(arg))
    if not matched and not glob_module.has_magic(arg):
        # Literal path that doesn't exist — return it so the caller can report
        return [arg]
    return matched


def main():
    if len(sys.argv) < 2:
        print("Usage: runner.py <path-or-glob>", file=sys.stderr)
        sys.exit(2)

    arg = sys.argv[1]
    paths = resolve_paths(arg)

    ok_count = 0
    invalid_count = 0
    parse_error = False
    output_lines = []

    for path in paths:
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
