#!/usr/bin/env bash
# Sprawl / Mystery-House signal scan. Reports metric values + WARN/ALARM verdict.
# Reads-only. Run from repo root. No writes anywhere.
#
# Reasoning (Lesson 7, Breunig 2026-03-26): unbounded skill/plugin growth at
# machine speed creates Mystery-House sprawl — additive, idiosyncratic,
# eventually unmaintainable. Periodic measurement catches it early.

set -u
cd "${1:-.}"

# 1. Plugin count
PLUGINS=$(/usr/bin/find plugins -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)

# 2. Skills-per-plugin: list, then max + stddev
SKILLS_PER_PLUGIN=$(for d in plugins/*/; do
  count=$(/usr/bin/find "$d" -name SKILL.md 2>/dev/null | wc -l)
  printf '%s\n' "$count"
done)
MAX_SKILLS=$(printf '%s\n' "$SKILLS_PER_PLUGIN" | sort -n | tail -1)
MIN_SKILLS=$(printf '%s\n' "$SKILLS_PER_PLUGIN" | sort -n | head -1)
STDDEV=$(printf '%s\n' "$SKILLS_PER_PLUGIN" | awk '{s+=$1; ss+=$1*$1; n++} END{ if(n>0){m=s/n; v=ss/n - m*m; if(v<0)v=0; printf "%.1f", sqrt(v) } else print "0" }')

# 3. Hook-event collision: how many plugins register hooks on each event?
EVENT_COUNTS=$(python3 - <<'PY'
import json, glob
from collections import Counter
events = Counter()
for path in sorted(glob.glob('plugins/*/hooks/hooks.json')):
    plugin = path.split('/')[1]
    try:
        data = json.load(open(path))
    except Exception:
        continue
    for ev in (data.get('hooks') or {}).keys():
        events[(ev, plugin)] += 1
plugins_per_event = Counter()
for (ev, plugin), _n in events.items():
    plugins_per_event[ev] += 1
if plugins_per_event:
    ev, n = plugins_per_event.most_common(1)[0]
    print(f"{ev}\t{n}")
else:
    print("\t0")
PY
)
TOP_EVENT=$(printf '%s' "$EVENT_COUNTS" | cut -f1)
TOP_EVENT_PLUGINS=$(printf '%s' "$EVENT_COUNTS" | cut -f2)

# 4. Cross-plugin references: count mentions of `plugins/<other>/` inside a plugin's files
XREF=$(python3 - <<'PY'
import os, re, glob
plugins = [d.split('/')[1] for d in glob.glob('plugins/*/') if os.path.isdir(d)]
pat = re.compile(r'plugins/(' + '|'.join(re.escape(p) for p in plugins) + r')/')
total = 0
for self_plugin in plugins:
    for root, _dirs, files in os.walk(f'plugins/{self_plugin}'):
        for fname in files:
            if not fname.endswith(('.md','.sh','.json','.py')): continue
            path = os.path.join(root, fname)
            try:
                txt = open(path, encoding='utf-8', errors='ignore').read()
            except Exception:
                continue
            for m in pat.finditer(txt):
                if m.group(1) != self_plugin:
                    total += 1
print(total)
PY
)

verdict() {
  local val="$1" warn="$2" alarm="$3"
  if [ "$val" -ge "$alarm" ]; then echo "ALARM"
  elif [ "$val" -ge "$warn" ]; then echo "WARN"
  else echo "OK"; fi
}

V_PLUGINS=$(verdict "$PLUGINS" 25 35)
V_MAXSK=$(verdict "$MAX_SKILLS" 20 30)
V_EVENT=$(verdict "$TOP_EVENT_PLUGINS" 5 8)
V_XREF=$(verdict "$XREF" 30 50)

cat <<EOF
[entropy-scan/sprawl] Mystery-House signals (Source: Breunig 2026-03-26, Lesson 7)
  Plugin count            : $PLUGINS  → $V_PLUGINS  (warn≥25, alarm≥35)
  Max skills/plugin       : $MAX_SKILLS  (stddev=$STDDEV, min=$MIN_SKILLS)  → $V_MAXSK  (warn≥20, alarm≥30)
  Top hook-event ($TOP_EVENT) plugins  : $TOP_EVENT_PLUGINS  → $V_EVENT  (warn≥5, alarm≥8)
  Cross-plugin references : $XREF  → $V_XREF  (warn≥30, alarm≥50)
EOF

case "$V_PLUGINS$V_MAXSK$V_EVENT$V_XREF" in
  *WARN*|*ALARM*) exit 1 ;;
esac
exit 0
