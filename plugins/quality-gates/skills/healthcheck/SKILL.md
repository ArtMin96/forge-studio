---
name: healthcheck
description: Run a full project health check. Pint (formatting) then PHPStan/Larastan (static analysis) then Pest (tests). Use before committing or when you want a quality snapshot.
disable-model-invocation: true
argument-hint: [--quick|--full]
allowed-tools:
  - Bash
  - Read
  - Glob
---

# Healthcheck: One-Command Project Quality

Runs a sequential pipeline. Stops at the first failure unless `--full` is passed.

## Pipeline

### Step 1: Formatting (Pint/php-cs-fixer)
```bash
# Try Pint first, fall back to php-cs-fixer
./vendor/bin/pint --test 2>/dev/null || php-cs-fixer fix --dry-run --diff 2>/dev/null
```
Report: files that need formatting

### Step 2: Static Analysis (PHPStan/Larastan)
```bash
./vendor/bin/phpstan analyse --no-progress 2>/dev/null
```
Report: errors found, severity

### Step 3: Tests (Pest/PHPUnit) — skipped with `--quick`
```bash
./vendor/bin/pest --no-coverage 2>/dev/null || ./vendor/bin/phpunit 2>/dev/null
```
Report: tests passed/failed

## Arguments
- `--quick`: Steps 1-2 only (formatting + static analysis). Fast.
- `--full` (default): All 3 steps including tests.

## Output
```
HEALTHCHECK
===========
Formatting:      [PASS/FAIL] — [X files need formatting]
Static Analysis: [PASS/FAIL] — [X errors]
Tests:           [PASS/FAIL/SKIPPED] — [X passed, Y failed]
---
Overall:         [HEALTHY / NEEDS ATTENTION]
```

If something fails, show the actual errors (first 10 lines) so they can be fixed immediately.
