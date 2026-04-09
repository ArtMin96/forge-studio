#!/usr/bin/env bash
# Quality Gates: Run static analysis on JS/TS files after write/edit.
# Only triggers for .js/.jsx/.ts/.tsx files.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$FILE" ]; then
  exit 0
fi

# Only check JS/TS files
case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx) ;;
  *) exit 0 ;;
esac

# Run TypeScript compiler if tsconfig.json exists
if [ -f "tsconfig.json" ] && command -v npx &>/dev/null; then
  RESULT=$(npx tsc --noEmit 2>&1)
  if [ $? -ne 0 ] && [ -n "$RESULT" ]; then
    echo "TypeScript errors:"
    echo "$RESULT" | head -10
    HAS_ISSUES=1
  fi
fi

# Run ESLint if configured
ESLINT_CONFIG=""
for f in .eslintrc .eslintrc.js .eslintrc.json .eslintrc.yml eslint.config.js eslint.config.mjs eslint.config.ts; do
  if [ -f "$f" ]; then
    ESLINT_CONFIG="$f"
    break
  fi
done

if [ -n "$ESLINT_CONFIG" ] && command -v npx &>/dev/null; then
  RESULT=$(npx eslint --quiet "$FILE" 2>&1)
  if [ $? -ne 0 ] && [ -n "$RESULT" ]; then
    echo "ESLint issues in $FILE:"
    echo "$RESULT" | head -10
    HAS_ISSUES=1
  fi
fi

if [ "${HAS_ISSUES:-0}" = "1" ]; then
  exit 1
fi

exit 0
