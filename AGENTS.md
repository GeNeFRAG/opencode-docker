# Project Context

This repo is **CodeBox** — a Docker wrapper for [OpenCode](https://github.com/opencode-ai/opencode), [Claude Code](https://github.com/anthropics/claude-code), and [FlowCode](https://flowcode.dev). It does not contain the agent applications themselves — it packages them into a container with MCP servers, a prefill proxy, and browser-accessible UI modes (web, tui, tmux).

## Key Files

| File | What it configures |
|------|--------------------|
| `entrypoint.sh` | Container startup orchestrator — sources all `lib/` scripts in order |
| `lib/env.sh` | Loads `.env` file; warns about non-reloadable variables; deprecation shim for old `OPENCODE_*` shared vars |
| `lib/config.sh` | Config generation for all three agents (opencode, claude-code, flowcode), auth.json writing, host-auth merging |
| `lib/ca-cert.sh` | Corporate CA certificate installation into system store |
| `lib/plugins.sh` | OpenCode npm plugin installation (oh-my-opencode-slim) |
| `lib/system-checks.sh` | Docker socket check, git safe.directory, workspace symlink, git credentials/work config validation |
| `lib/proxy.sh` | Prefill proxy start/stop helpers (OpenCode only) |
| `lib/runtime.sh` | Binary resolution (`APP_BIN`), startup banner, model cache refresh, FlowCode mode guard, theme initialization, browser tab title derivation |
| `lib/modes.sh` | Mode launch: `web` / `tui` / `tmux` restart loops |
| `templates/opencode.json.template` | OpenCode config — MCP servers, permissions, provider endpoints |
| `templates/claude-code.mcp.json.template` | Claude Code MCP server config template |
| `templates/flowcode.mcp.json.template` | FlowCode MCP server config template |
| `templates/oh-my-opencode-slim.json.template` | Agent preset — which model/skills/MCPs each agent role uses + fallback chains |
| `proxy/prefill-proxy.mjs` | Local HTTP proxy that strips assistant prefill messages before forwarding to the LLM (OpenCode only) |
| `docker-compose.yml` | Base service definition (volumes, healthcheck, resource limits) |
| `codebox.sh` | Host CLI wrapper for docker compose operations |
| `tmux/tmux.conf` | tmux keybindings and status bar config (tmux mode only) |
| `tmux/tmux-theme-dark.conf` / `tmux/tmux-theme-light.conf` | Dark/light theme overrides for tmux status bar |
| `tmux/tmux-theme-toggle.sh` | Runtime dark/light theme toggle (bound to `Ctrl-Space t`) |
| `tmux/agent-monitor.sh` / `tmux/agent-status.sh` / `tmux/session-status.sh` | tmux status bar and monitor pane — poll the SQLite DB for subagent activity (OpenCode only) |
| `tmux/session-status-claude.sh` | Simplified tmux status bar for Claude Code (no model/context data) |
| `tmux/agent-monitor-toggle.sh` | Toggles the monitor pane on/off |

## Conventions

- Environment variables use the `CODEBOX_` prefix for shared settings (app, mode, port, theme, etc.). OpenCode-specific vars (`OPENCODE_MODEL`, `OPENCODE_MODEL_FALLBACK`, `OPENCODE_TUI_THEME`) keep the `OPENCODE_` prefix. A deprecation shim in `lib/env.sh` maps old `OPENCODE_*` shared vars to `CODEBOX_*` with a warning.
- Environment variables are documented in `.env.example` and substituted into configs by `lib/config.sh` via `envsubst`.
- MCP servers for OpenCode are defined in `templates/opencode.json.template`. Claude Code uses `templates/claude-code.mcp.json.template`. FlowCode uses `templates/flowcode.mcp.json.template`. Enabled servers run as Node processes inside the container; disabled ones (github, atlassian, grafana) require Docker socket access.
- Shell scripts target `bash` and run inside the container at `/opt/opencode/`. The `entrypoint.sh` is the only script executed directly; everything else is sourced.
- The `oh-my-opencode-slim` plugin is an npm package baked into the image. Its config template lives at `templates/oh-my-opencode-slim.json.template`; the active config lives at `/root/.config/opencode/oh-my-opencode-slim.json`.
- FlowCode is web-only (`CODEBOX_MODE` is forced to `web` if another value is set). Its config and credentials are written to `/root/.config/flowcode/` at startup.
- The three agent binaries are all available in the container at `/usr/local/bin/`: `opencode`, `claude` (Claude Code), and `flowcode-server` (FlowCode). `CODEBOX_APP` selects which one runs.
