#!/usr/bin/env bash
# Read-only staleness scoring for every plugins/**/SKILL.md.
# Composable with /auto-tune-skill via --format=json output.

set -euo pipefail

FORMAT="human"
THRESHOLD_STALE="0.50"
THRESHOLD_AGING="0.75"

for arg in "$@"; do
  case "$arg" in
    --format=*) FORMAT="${arg#--format=}" ;;
    --threshold-stale=*) THRESHOLD_STALE="${arg#--threshold-stale=}" ;;
    --threshold-aging=*) THRESHOLD_AGING="${arg#--threshold-aging=}" ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--format=human|json] [--threshold-stale=0.5] [--threshold-aging=0.75]
EOF
      exit 0
      ;;
  esac
done

NOW=$(date -u +%s)
RUNS_AT=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# Use git's repo root rather than $PWD so the script works from any subdirectory.
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
cd "$REPO_ROOT"

score_skill() {
  local skill_md="$1"
  local skill_dir
  skill_dir=$(dirname "$skill_md")

  # Signal 1: edit recency (0.25)
  # Use commit time, not filesystem mtime — survives clones/copies.
  local commit_ts age_days recency
  commit_ts=$(git log -1 --format=%ct -- "$skill_md" 2>/dev/null)
  if ! [[ "$commit_ts" =~ ^[0-9]+$ ]]; then
    recency="0.5"
    age_days="?"
  else
    age_days=$(( (NOW - commit_ts) / 86400 ))
    if [ "$age_days" -le 30 ]; then
      recency="1.0"
    elif [ "$age_days" -ge 365 ]; then
      recency="0.0"
    else
      # linear decay 30 → 365 days (335-day window)
      recency=$(awk -v a="$age_days" 'BEGIN{printf "%.4f", (365 - a) / 335}')
    fi
  fi

  # Signal 2: eval coverage (0.20)
  local evals
  if [ -f "$skill_dir/evals/evals.json" ]; then evals="1.0"; else evals="0.0"; fi

  # Signal 3: SSL overlay completeness (0.15)
  # Frontmatter is the YAML between the first two `---` lines.
  local fm
  fm=$(awk '/^---$/{c++; next} c==1' "$skill_md" 2>/dev/null)
  local ssl_count=0
  echo "$fm" | grep -qE '^scheduling:' && ssl_count=$((ssl_count + 1))
  echo "$fm" | grep -qE '^structural:' && ssl_count=$((ssl_count + 1))
  echo "$fm" | grep -qE '^logical:' && ssl_count=$((ssl_count + 1))
  local ssl
  ssl=$(awk -v n="$ssl_count" 'BEGIN{printf "%.4f", n/3}')

  # Signal 4: citation freshness (0.15)
  # arXiv IDs follow YYMM.NNNNN — extract YYMM, compute age in months.
  local newest_id newest_age_months citation
  newest_id=$(grep -oE 'arXiv:?[[:space:]]*2[0-9]{3}\.[0-9]{4,5}' "$skill_md" 2>/dev/null \
    | grep -oE '2[0-9]{3}' | sort -n | tail -1)
  if [ -z "$newest_id" ]; then
    citation="0.5"  # no citation → neutral, not penalized
    newest_age_months="-"
  else
    local cite_year cite_month now_year now_month
    cite_year="20${newest_id:0:2}"
    cite_month="${newest_id:2:2}"
    now_year=$(date -u +%Y)
    now_month=$(date -u +%m)
    newest_age_months=$(( (10#$now_year - 10#$cite_year) * 12 + 10#$now_month - 10#$cite_month ))
    if [ "$newest_age_months" -le 18 ]; then
      citation="1.0"
    elif [ "$newest_age_months" -le 36 ]; then
      citation="0.5"
    else
      citation="0.0"
    fi
  fi

  # Signal 5: description budget (0.10)
  # Combined description + when_to_use chars vs 1536 cap.
  local desc_chars budget
  desc_chars=$(awk '
    /^---$/ { c++; next }
    c == 1 && /^(description|when_to_use):/ { in_field = 1; sub(/^[^:]+:[[:space:]]*/, ""); print; next }
    c == 1 && in_field && /^[a-zA-Z_-]+:/ { in_field = 0; next }
    c == 1 && in_field { print }
  ' "$skill_md" | wc -c)
  if [ "$desc_chars" -le 1280 ]; then
    budget="1.0"
  elif [ "$desc_chars" -ge 1536 ]; then
    budget="0.0"
  else
    budget=$(awk -v c="$desc_chars" 'BEGIN{printf "%.4f", (1536 - c) / 256}')
  fi

  # Signal 6: exclusion clause (0.10)
  local exclusion
  if grep -q "Do NOT use for" "$skill_md"; then exclusion="1.0"; else exclusion="0.0"; fi

  # Signal 7: helper extraction (0.05)
  # Penalize SKILL.md bodies that contain code fences ≥10 lines (helpers belong in scripts/).
  local helper inline_max
  inline_max=$(awk '
    /^```/ { in_block = !in_block; if (!in_block) { if (lines > max) max = lines; lines = 0 }; next }
    in_block { lines++ }
    END { print max+0 }
  ' "$skill_md")
  if [ "$inline_max" -lt 10 ]; then helper="1.0"; else helper="0.0"; fi

  # Weighted sum
  local total
  total=$(awk -v r="$recency" -v e="$evals" -v s="$ssl" -v c="$citation" -v b="$budget" -v x="$exclusion" -v h="$helper" \
    'BEGIN{printf "%.4f", r*0.25 + e*0.20 + s*0.15 + c*0.15 + b*0.10 + x*0.10 + h*0.05}')

  # Tier
  local tier
  if awk -v t="$total" -v s="$THRESHOLD_STALE" 'BEGIN{exit !(t<s)}'; then
    tier="stale"
  elif awk -v t="$total" -v a="$THRESHOLD_AGING" 'BEGIN{exit !(t<a)}'; then
    tier="aging"
  else
    tier="fresh"
  fi

  # Tab-separated for the caller to format. Fields: path, total, tier, age_days,
  # evals(0/1), ssl(0-3), citation_age_months_or_-, desc_chars, exclusion(0/1), inline_max
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$skill_md" "$total" "$tier" "$age_days" "$evals" "$ssl_count" "$newest_age_months" "$desc_chars" "$exclusion" "$inline_max"
}

# Collect rows
ROWS=$(find plugins -name SKILL.md -not -path 'plugins/_*' 2>/dev/null \
  | sort \
  | while read -r f; do score_skill "$f"; done)

TOTAL_SKILLS=$(printf '%s\n' "$ROWS" | wc -l)
N_STALE=$(printf '%s\n' "$ROWS" | awk -F'\t' '$3=="stale"' | wc -l)
N_AGING=$(printf '%s\n' "$ROWS" | awk -F'\t' '$3=="aging"' | wc -l)
N_FRESH=$(printf '%s\n' "$ROWS" | awk -F'\t' '$3=="fresh"' | wc -l)

if [ "$FORMAT" = "json" ]; then
  printf '{"runs_at":"%s","totals":{"skills":%d,"stale":%d,"aging":%d,"fresh":%d},"skills":[' \
    "$RUNS_AT" "$TOTAL_SKILLS" "$N_STALE" "$N_AGING" "$N_FRESH"
  first=1
  printf '%s\n' "$ROWS" | while IFS=$'\t' read -r path score tier age evals ssl cite desc excl inline; do
    [ -z "$path" ] && continue
    if [ "$first" = "1" ]; then first=0; else printf ','; fi
    printf '{"path":"%s","score":%s,"tier":"%s","signals":{"age_days":"%s","evals":%s,"ssl":%s,"citation_age_months":"%s","description_chars":%s,"exclusion_clause":%s,"max_inline_block_lines":%s}}' \
      "$path" "$score" "$tier" "$age" "$evals" "$ssl" "$cite" "$desc" "$excl" "$inline"
  done
  printf ']}\n'
  exit 0
fi

# Human format
printf 'SKILL STALENESS AUDIT — %d skills, run at %s\n\n' "$TOTAL_SKILLS" "$RUNS_AT"
for tier_name in stale aging fresh; do
  case "$tier_name" in
    stale) header="STALE (<$THRESHOLD_STALE)" ; n="$N_STALE" ;;
    aging) header="AGING ($THRESHOLD_STALE–$THRESHOLD_AGING)" ; n="$N_AGING" ;;
    fresh) header="FRESH (>=$THRESHOLD_AGING)" ; n="$N_FRESH" ;;
  esac
  printf '%s: %d skills\n' "$header" "$n"
  printf '%s\n' "$ROWS" | awk -F'\t' -v t="$tier_name" '$3==t' \
    | sort -t$'\t' -k2,2g \
    | while IFS=$'\t' read -r path score tier age evals ssl cite desc excl inline; do
        e=$([ "$evals" = "1.0" ] && echo "yes" || echo "no")
        printf '  %.2f  %-70s age:%sd  evals:%-3s  ssl:%s/3  cite:%s\n' \
          "$score" "$path" "$age" "$e" "$ssl" "$cite"
      done
  printf '\n'
done
