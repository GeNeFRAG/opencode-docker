#!/bin/bash
set -e

CONFIG_DIR="/root/.config/opencode"
DATA_DIR="/root/.local/share/opencode"
TEMPLATE="/opt/opencode/opencode.json.template"
CONFIG_FILE="${CONFIG_DIR}/opencode.json"

echo "╔══════════════════════════════════════════╗"
echo "║       OpenCode Web - Docker Container     ║"
echo "╚══════════════════════════════════════════╝"

# ─── Generate opencode.json from template + env vars ───────────────
echo "→ Generating opencode.json from template..."

# Only substitute our known variables (avoids clobbering $schema etc.)
envsubst '${RBIGENAI_BASE_URL} ${RBIGENAI_API_KEY} ${OPENROUTER_API_KEY} ${OPENCODE_MODEL} ${GITHUB_RBI_TOKEN} ${GITHUB_PERSONAL_TOKEN} ${CONFLUENCE_URL} ${CONFLUENCE_USERNAME} ${CONFLUENCE_TOKEN} ${JIRA_URL} ${JIRA_USERNAME} ${JIRA_TOKEN} ${GRAFANA_URL} ${GRAFANA_API_KEY}' \
    < "${TEMPLATE}" > "${CONFIG_FILE}"

echo "  ✓ Config written to ${CONFIG_FILE}"

# ─── Generate auth.json if API key is set ──────────────────────────
AUTH_FILE="${DATA_DIR}/auth.json"
if [ -n "${RBIGENAI_API_KEY}" ]; then
    echo "→ Writing auth.json..."
    cat > "${AUTH_FILE}" <<EOF
{
  "anthropic": {
    "type": "api",
    "key": "${RBIGENAI_API_KEY}"
  },
  "RBIGenAI": {
    "type": "api",
    "key": "${RBIGENAI_API_KEY}"
  }
}
EOF
    echo "  ✓ Auth configured"
fi

# ─── Handle Zscaler/corporate CA certificates ─────────────────────
if [ -f "/certs/zscaler.pem" ]; then
    echo "→ Installing corporate CA certificate..."
    cp /certs/zscaler.pem /usr/local/share/ca-certificates/zscaler.crt
    update-ca-certificates 2>/dev/null
    export NODE_EXTRA_CA_CERTS="/certs/zscaler.pem"
    export REQUESTS_CA_BUNDLE="/certs/zscaler.pem"
    echo "  ✓ CA certificate installed"
fi

# ─── Install opencode plugins if package.json exists ───────────────
if [ -f "${CONFIG_DIR}/package.json" ]; then
    echo "→ Ensuring opencode plugins are installed..."
    cd "${CONFIG_DIR}" && npm install --prefer-offline --no-audit --no-fund 2>/dev/null
    echo "  ✓ Plugins ready"
fi

# ─── Ensure .opencode project config is available ──────────────────
if [ -d "/workspace/.opencode" ]; then
    echo "  ✓ Project .opencode directory found"
fi

# ─── Docker socket check (for MCP servers) ────────────────────────
if [ -S "/var/run/docker.sock" ]; then
    echo "  ✓ Docker socket available (MCP containers supported)"
else
    echo "  ⚠ Docker socket not mounted - Docker-based MCP servers will not work"
fi

# ─── Git configuration ────────────────────────────────────────────
# Host .gitconfig is mounted read-only; use env vars to add safe.directory
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="safe.directory"
export GIT_CONFIG_VALUE_0="/workspace"

echo ""
echo "→ Starting opencode web on 0.0.0.0:${OPENCODE_PORT:-3000}..."
echo "  Access: http://localhost:${OPENCODE_PORT:-3000}"
echo ""

# ─── Start opencode web ──────────────────────────────────────────
exec opencode web \
    --hostname 0.0.0.0 \
    --port "${OPENCODE_PORT:-3000}" \
    ${OPENCODE_EXTRA_ARGS:-}
