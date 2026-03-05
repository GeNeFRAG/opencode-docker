#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# agent-status.sh — tmux status bar: active subagent count + names
# ═══════════════════════════════════════════════════════════════════
# Called by tmux status-right every status-interval seconds.
# Queries the opencode SQLite database for active subagent sessions.
# Outputs a short tmux-formatted string like "2 ⚡explorer·fixer"
# or empty string when idle.
#
# Usage: bash /opt/opencode/agent-status.sh

# A session is "active" if its most recent message arrived within
# this threshold.  Must be generous enough for agents that pause
# while thinking (oracle can pause 10-20s between messages).
# This threshold is intentionally aligned with STABLE_THRESHOLD × POLL_INTERVAL
# in agent-monitor.sh (5×2=10s) so both scripts agree on what's active.
ACTIVE_THRESHOLD_MS=15000

now_ms=$(date +%s%3N 2>/dev/null || echo "0")
STARTUP_TS=$(cat /tmp/.opencode-startup-ts 2>/dev/null || echo "0")

# Query active subagent sessions (only from current container lifecycle).
# Uses a pre-aggregated subquery instead of correlated subqueries for speed.
result=$(opencode db "
    SELECT
        COALESCE(first_msg.agent, 'unknown') as agent
    FROM session s
    LEFT JOIN (
        SELECT
            m.session_id,
            json_extract(m.data, '\$.agent') as agent
        FROM message m
        INNER JOIN (
            SELECT session_id, MIN(rowid) as min_rowid
            FROM message
            GROUP BY session_id
        ) fm ON m.session_id = fm.session_id AND m.rowid = fm.min_rowid
    ) first_msg ON first_msg.session_id = s.id
    LEFT JOIN (
        SELECT session_id, MAX(time_created) as last_msg_time
        FROM message
        GROUP BY session_id
    ) agg ON agg.session_id = s.id
    WHERE s.parent_id IS NOT NULL
      AND s.time_created >= ${STARTUP_TS}
      AND (${now_ms} - COALESCE(agg.last_msg_time, s.time_created)) < ${ACTIVE_THRESHOLD_MS}
    ORDER BY s.time_created ASC
" --format tsv 2>/dev/null | tail -n +2)  # skip header

[ -z "$result" ] && { echo ""; exit 0; }

# Deduplicate agent names and count
declare -A names
count=0
while IFS= read -r agent; do
    [ -z "$agent" ] && continue
    names["$agent"]=1
    count=$((count + 1))
done <<< "$result"

if [ "$count" -eq 0 ]; then
    echo ""
else
    name_list=$(echo "${!names[@]}" | tr ' ' '·')
    echo "#[fg=#e0af68,bold]${count}#[fg=#565f89] ⚡#[fg=#a9b1d6]${name_list}"
fi
