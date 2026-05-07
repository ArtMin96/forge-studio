#!/usr/bin/env bash
# PreToolUse(Edit|Write|Bash): when Claude is about to touch a file with broad
# blast radius (dependency manifest, lockfile, CI config, build/orchestration
# file, top-level config, schema/migration, repo-wide doc), inject an
# additionalContext reminder describing the file's role and prompting Claude to
# call code-review-graph MCP `get_impact_radius_tool` for callers/dependents.
#
# Project-agnostic: matches by canonical filename patterns common across
# JS/TS/PHP/Python/Go/Ruby/Rust ecosystems. Advisory only; never blocks.

set -u

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat 2>/dev/null || true)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# For Bash, extract a written-to path from common write idioms.
if [ -z "$FILE_PATH" ] && [ "$TOOL" = "Bash" ]; then
  CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
  FILE_PATH=$(echo "$CMD" | grep -oE '(>>?|tee|sed -i|awk -i inplace) +[^ |&;<>]+' \
    | head -1 | awk '{print $NF}' | tr -d '"'"'")
fi

[ -z "$FILE_PATH" ] && exit 0

REL=$(echo "$FILE_PATH" | sed "s|^$(pwd)/||")
BASE=$(basename "$REL")

ROLE=""
HINT=""

# Match canonical broad-blast files. Order: most-specific patterns first.
case "$REL" in
  # CI / pipeline configs — change here affects every build.
  .github/workflows/*.yml|.github/workflows/*.yaml|.gitlab-ci.yml|.circleci/config.yml|azure-pipelines.yml|bitbucket-pipelines.yml|Jenkinsfile)
    ROLE="CI pipeline config"
    HINT="run validation on a feature branch first; downstream jobs and required-status-checks may break across all PRs."
    ;;
  # Container / orchestration.
  Dockerfile|*.Dockerfile|docker-compose*.yml|docker-compose*.yaml|compose.yml|compose.yaml|kubernetes/*.yml|kubernetes/*.yaml|k8s/*.yml|k8s/*.yaml|helm/**/values.yaml)
    ROLE="container/orchestration manifest"
    HINT="rebuilds invalidate image caches; check that all environments + CI workflows reference the same tag/digest."
    ;;
  # Build files.
  Makefile|*.mk|build.gradle|build.gradle.kts|pom.xml|BUILD|BUILD.bazel|WORKSPACE)
    ROLE="build file"
    HINT="changes here affect every developer build and CI; run a clean build to confirm."
    ;;
  *)
    case "$BASE" in
      # Dependency manifests.
      package.json|composer.json|pyproject.toml|requirements.txt|requirements-*.txt|Pipfile|Cargo.toml|go.mod|Gemfile|build.sbt|deno.json|bun.lockb)
        ROLE="dependency manifest ($BASE)"
        HINT="version bumps and additions ripple through every consumer; check the lockfile is regenerated and CI cache key includes it."
        ;;
      # Lockfiles — never hand-edit.
      composer.lock|package-lock.json|yarn.lock|pnpm-lock.yaml|Pipfile.lock|poetry.lock|Cargo.lock|Gemfile.lock|go.sum)
        ROLE="lockfile ($BASE)"
        HINT="lockfiles are usually regenerated via the package manager — hand-edits cause integrity mismatches. Prefer the package manager command unless you know exactly why you're hand-editing."
        ;;
      # Top-level config (linters, type-checkers, formatters).
      tsconfig.json|tsconfig.*.json|.eslintrc|.eslintrc.*|.prettierrc|.prettierrc.*|.babelrc|.babelrc.*|babel.config.*|jest.config.*|vite.config.*|vitest.config.*|webpack.config.*|rollup.config.*|next.config.*|nuxt.config.*|svelte.config.*|tailwind.config.*|postcss.config.*|phpstan.neon|phpstan.neon.dist|phpunit.xml|phpunit.xml.dist|.php-cs-fixer.*|pint.json|pyproject.toml|setup.cfg|tox.ini|.flake8|mypy.ini|ruff.toml|.rubocop.yml|.golangci.yml|.golangci.yaml|biome.json|biome.jsonc)
        ROLE="tooling config ($BASE)"
        HINT="every developer + every CI job reads this; rules added here can fail commits silently. Run the tool against the full repo after the change."
        ;;
      # Schema / migrations / structural data.
      schema.prisma|schema.rb|*.sql)
        case "$REL" in
          *migrations/*|*migration/*|*db/migrate/*|*alembic/versions/*|*ent/migrate/*)
            ROLE="database migration"
            HINT="migrations are append-only in production. Check whether this is being added forward-only or whether you're modifying a deployed migration."
            ;;
          *)
            ROLE="schema file"
            HINT="schema changes ripple through models, queries, types, and tests. Check generated client / model files."
            ;;
        esac
        ;;
      # Repo-wide docs.
      README|README.md|README.rst|CONTRIBUTING.md|CODE_OF_CONDUCT.md|CHANGELOG|CHANGELOG.md|LICENSE|LICENSE.md)
        ROLE="repo-wide doc ($BASE)"
        HINT="external readers (npm/Packagist/PyPI/crates.io listings, docs sites) often pull from these; verify rendering in the registry preview if published."
        ;;
      # Environment / runtime entry points.
      .env|.env.*|*.env)
        ROLE="environment file ($BASE)"
        HINT="never commit secrets; verify .gitignore excludes the file and that any new keys are documented in .env.example."
        ;;
      *)
        exit 0
        ;;
    esac
    ;;
esac

CTX="[preflight] About to ${TOOL} ${REL} (${ROLE}). ${HINT} For callers/dependents in this repo, the code-review-graph MCP exposes mcp__code-review-graph__get_impact_radius_tool."

jq -nc --arg c "$CTX" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: $c
  }
}'
exit 0
