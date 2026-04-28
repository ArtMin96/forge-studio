---
name: healthcheck
description: Use when the user wants a one-command quality snapshot — auto-detects PHP and/or JS/TS projects and runs the appropriate pipeline (composer install + pest + pint + phpstan; npm install + tests + lint + typecheck). Returns a single PASS/WARN/FAIL summary plus the offending tool's output.
when_to_use: Reach for this before committing, before opening a PR, or whenever the user asks "is this healthy?" without specifying a tool. Do NOT use to audit Forge Studio's marketplace integrity — that's `/validate-marketplace` and `/entropy-scan`; healthcheck targets the user's actual project code.
disable-model-invocation: true
effort: high
argument-hint: [--quick|--full]
allowed-tools:
  - Bash
  - Read
  - Glob
---

# Healthcheck: One-Command Project Quality

Detects the project type and runs the appropriate pipeline. Stops at the first failure unless `--full` is passed.

## Project Detection

Check what's available:
```bash
# PHP project?
test -f composer.json && echo "PHP detected"
# JS/TS project?
test -f package.json && echo "JS detected"
test -f tsconfig.json && echo "TypeScript detected"
```

Run the pipeline for each detected language.

## PHP Pipeline

### Step 1: Formatting (Pint/php-cs-fixer)
```bash
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

## JS/TS Pipeline

### Step 1: Formatting (Prettier/ESLint style rules)
```bash
npx prettier --check "src/**/*.{ts,tsx,js,jsx}" 2>/dev/null
```
Report: files that need formatting

### Step 2: Type Check + Linting
```bash
npx tsc --noEmit 2>/dev/null
npx eslint . --quiet 2>/dev/null
```
Report: type errors, lint issues

### Step 3: Tests (Vitest/Jest) — skipped with `--quick`
```bash
npx vitest run 2>/dev/null || npx jest --no-coverage 2>/dev/null
```
Report: tests passed/failed

## Arguments
- `--quick`: Formatting + static analysis only. Fast.
- `--full` (default): All steps including tests.

## Output
```
HEALTHCHECK
===========
[PHP]
Formatting:      [PASS/FAIL/SKIP] — [details]
Static Analysis: [PASS/FAIL/SKIP] — [details]
Tests:           [PASS/FAIL/SKIP] — [details]

[JS/TS]
Formatting:      [PASS/FAIL/SKIP] — [details]
Type Check:      [PASS/FAIL/SKIP] — [details]
Lint:            [PASS/FAIL/SKIP] — [details]
Tests:           [PASS/FAIL/SKIP] — [details]
---
Overall:         [HEALTHY / NEEDS ATTENTION]
```

If something fails, show the actual errors (first 10 lines) so they can be fixed immediately.
