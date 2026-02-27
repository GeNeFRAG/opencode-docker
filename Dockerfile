# ═══════════════════════════════════════════════════════════════════
# Build stage: has build-essential for native npm modules
# ═══════════════════════════════════════════════════════════════════
FROM node:22-bookworm-slim AS builder

COPY zscaler.pem /usr/local/share/ca-certificates/zscaler.crt
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates build-essential python3 curl \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/zscaler.crt
ENV NODE_OPTIONS="--use-openssl-ca"

# Install opencode-ai globally
RUN npm install -g opencode-ai@1.2.10

# Install provider SDKs and plugins
RUN mkdir -p /root/.config/opencode && \
    echo '{"dependencies":{"@ai-sdk/openai-compatible":"latest","@ai-sdk/groq":"^3.0.24","@opencode-ai/plugin":"1.2.10","@openrouter/ai-sdk-provider":"^2.2.3"}}' \
    > /root/.config/opencode/package.json && \
    cd /root/.config/opencode && npm install

# Pre-install MCP server packages (cached for fast startup)
RUN npx -y @modelcontextprotocol/server-memory@latest --help 2>/dev/null || true && \
    npx -y @upstash/context7-mcp@latest --help 2>/dev/null || true && \
    npx -y @modelcontextprotocol/server-sequential-thinking@latest --help 2>/dev/null || true && \
    npx -y @anthropics/grep-app-mcp@latest --help 2>/dev/null || true && \
    npx -y mcp-time-server@latest --help 2>/dev/null || true && \
    npx -y @playwright/mcp@latest --help 2>/dev/null || true && \
    npx -y @cyanheads/git-mcp-server@latest --help 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════
# Runtime stage: slim, no build tools
# ═══════════════════════════════════════════════════════════════════
FROM node:22-bookworm-slim AS runtime

LABEL maintainer="gerhard.froehlich"
LABEL description="OpenCode AI Web - persistent AI coding agent"

# ─── CA certificate ────────────────────────────────────────────────
COPY zscaler.pem /usr/local/share/ca-certificates/zscaler.crt
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/zscaler.crt
ENV NODE_OPTIONS="--use-openssl-ca"

# ─── Runtime tools only (NO build-essential, NO docker.io) ─────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        curl \
        openssh-client \
        jq \
        gettext-base \
        unzip \
        ripgrep \
    && rm -rf /var/lib/apt/lists/*

# ─── Docker CLI only (static binary, ~50 MB vs ~250 MB docker.io) ──
ARG DOCKER_VERSION=27.3.1
ARG TARGETARCH
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "aarch64" || echo "x86_64") && \
    curl -fsSL "https://download.docker.com/linux/static/stable/${ARCH}/docker-${DOCKER_VERSION}.tgz" \
    | tar xz --strip-components=1 -C /usr/local/bin docker/docker

# ─── Bun ───────────────────────────────────────────────────────────
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:$PATH"

# ─── Copy compiled artifacts from builder ──────────────────────────
COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=builder /root/.config/opencode/node_modules /root/.config/opencode/node_modules
COPY --from=builder /root/.config/opencode/package.json /root/.config/opencode/package.json
COPY --from=builder /root/.npm /root/.npm

# Re-create the opencode symlink (npm link gets lost across stages)
RUN ln -sf /usr/local/lib/node_modules/opencode-ai/bin/opencode /usr/local/bin/opencode

# ─── Workspace and data directories ───────────────────────────────
RUN mkdir -p /workspace \
    /root/.local/share/opencode \
    /root/.config/opencode/commands \
    /root/.config/opencode/skills \
    /root/.agents/skills

WORKDIR /workspace

# ─── Entrypoint and config ────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY opencode.json.template /opt/opencode/opencode.json.template
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:3000/ || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
