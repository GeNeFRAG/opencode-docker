# ─── lib/plugins.sh ─────────────────────────────────────────────────────────
# Install opencode npm plugins (if package.json exists in the config dir)
# and verify the presence of any project-level .opencode directory.

if [ "${OPENCODE_APP}" = "opencode" ] && [ -f "${CONFIG_DIR}/package.json" ]; then
    echo "→ Ensuring opencode plugins are installed..."
    if (cd "${CONFIG_DIR}" && npm install --prefer-offline --no-audit --no-fund 2>/dev/null); then
        echo "  ✓ Plugins ready"
    else
        echo "  ⚠ Plugin install failed (non-fatal) — continuing with cached modules"
    fi
fi

if [ "${OPENCODE_APP}" = "opencode" ] && [ -d "/workspace/.opencode" ]; then
    echo "  ✓ Project .opencode directory found"
fi
