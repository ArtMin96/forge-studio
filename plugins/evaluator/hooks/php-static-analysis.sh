#!/usr/bin/env bash
# Quality Gates: Run static analysis on PHP files after write/edit.
# Only triggers for .php files. Runs Larastan/PHPStan if available.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$FILE" ]; then
  exit 0
fi

# Only check PHP files
if [[ "$FILE" != *.php ]]; then
  exit 0
fi

# Check for migration files — verify down() method exists
if echo "$FILE" | grep -q "migrations/"; then
  if [ -f "$FILE" ]; then
    if ! grep -q "function down" "$FILE"; then
      echo "WARNING: Migration file is missing a down() method. Rollbacks won't work without it."
    fi
  fi
fi

# Run PHPStan/Larastan if available
if command -v vendor/bin/phpstan &>/dev/null && [ -f "phpstan.neon" -o -f "phpstan.neon.dist" ]; then
  RESULT=$(vendor/bin/phpstan analyse "$FILE" --no-progress --error-format=raw 2>/dev/null)
  if [ $? -ne 0 ] && [ -n "$RESULT" ]; then
    echo "PHPStan issues in $FILE:"
    echo "$RESULT" | head -10
    exit 1
  fi
elif command -v ./vendor/bin/phpstan &>/dev/null; then
  RESULT=$(./vendor/bin/phpstan analyse "$FILE" --no-progress --error-format=raw 2>/dev/null)
  if [ $? -ne 0 ] && [ -n "$RESULT" ]; then
    echo "PHPStan issues in $FILE:"
    echo "$RESULT" | head -10
    exit 1
  fi
fi

exit 0
