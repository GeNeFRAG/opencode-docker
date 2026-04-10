# ─── lib/env.sh ─────────────────────────────────────────────────────────────
# Reload .env from mounted file (picks up changes on stop/start) and warn
# about settings that require a full container recreate to take effect.

_load_env_file() {
    local env_file="$1"
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip blank lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # Strip optional 'export' prefix and any surrounding whitespace
        if [[ "$line" =~ ^[[:space:]]*export[[:space:]]+(.*) ]]; then
            line="${BASH_REMATCH[1]}"
        fi
        # Extract KEY and VALUE on first '='
        local key="${line%%=*}"
        local value="${line#*=}"
        # Validate key is a legal variable name
        [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || continue
        # Strip surrounding quotes from value (matching pairs only)
        if [[ "$value" =~ ^\"(.*)\"$ ]]; then
            value="${BASH_REMATCH[1]}"
        elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
            value="${BASH_REMATCH[1]}"
        fi
        export "$key=$value"
    done < "$env_file"
}

# Snapshot the port before loading so we can detect changes
_ORIG_PORT="${OPENCODE_PORT:-}"

if [ -f /opt/opencode/.env ] && [ -s /opt/opencode/.env ]; then
    _load_env_file /opt/opencode/.env
    echo "→ Reloaded environment from /opt/opencode/.env"
elif [ -f /workspace/.env ] && [ -s /workspace/.env ]; then
    _load_env_file /workspace/.env
    echo "→ Reloaded environment from /workspace/.env"
else
    echo "→ No .env file found (using container environment)"
fi

# ─── Warn about non-reloadable changes ─────────────────────────────
if [ "${OPENCODE_PORT:-}" != "${_ORIG_PORT}" ]; then
    if [ -n "${_ORIG_PORT}" ]; then
        echo "  ⚠ OPENCODE_PORT changed (${_ORIG_PORT} → ${OPENCODE_PORT}) — requires 'docker compose up' or './opencode-web.sh rebuild' to take effect"
        export OPENCODE_PORT="${_ORIG_PORT}"
    else
        echo "  ⚠ OPENCODE_PORT set to ${OPENCODE_PORT} via .env but port mapping was not configured at container creation — requires 'docker compose up' to take effect"
        unset OPENCODE_PORT
    fi
fi
unset _ORIG_PORT
