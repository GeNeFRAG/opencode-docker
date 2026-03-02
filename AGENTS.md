# Agent Architecture

OpenCode uses a multi-agent system where a central **orchestrator** delegates tasks to five specialist sub-agents. Each agent has its own model, quality variant, skills, and MCP server access — configured via the `oh-my-opencode-slim` plugin.

## Agent Roles

| Role | What it does | Default Model | Variant |
|------|-------------|---------------|---------|
| **orchestrator** | Top-level planning, tool use, delegation | `claude-opus-4-6` | — |
| **oracle** | Deep reasoning, architecture, complex debugging | `claude-opus-4-6` | high |
| **librarian** | Documentation lookup, library research | `claude-sonnet-4-6` | low |
| **explorer** | Fast codebase search, file/symbol discovery | `claude-haiku-4-5` | low |
| **designer** | UI/UX, styling, responsive layouts, visual polish | `claude-opus-4-6` | medium |
| **fixer** | Targeted code fixes, implementation | `claude-sonnet-4-6` | low |

**Variants** control quality/cost: `high` (max quality) · `medium` (balanced) · `low` (fast/cheap).

## How Delegation Works

1. The **orchestrator** receives the user's request
2. It analyses the task and selects the appropriate sub-agent via the `task` tool
3. The sub-agent runs autonomously with its own model and tool access
4. Results return to the orchestrator, which synthesises the final response

Sub-agents can run in parallel (up to ~10 concurrent). State is shared across agents via the `memory` MCP server.

### When Each Agent Is Used

| Agent | Triggered by |
|-------|-------------|
| **oracle** | Architecture decisions, persistent bugs (2+ failed fixes), high-risk refactors, security/scalability trade-offs |
| **librarian** | "How does library X work?", API lookups, version-specific behaviour, unfamiliar dependencies |
| **explorer** | "Where is X defined?", file discovery, pattern matching, broad codebase searches |
| **designer** | User-facing UI work, responsive layouts, visual polish, design system consistency |
| **fixer** | Well-defined implementation tasks, parallel code changes, repetitive multi-file edits |

## MCP Server Access per Role

Each role only gets the MCP servers it needs:

| Agent | MCP Servers |
|-------|-------------|
| **orchestrator** | `websearch`, `sequential-thinking`, `memory`, `time` |
| **oracle** | `sequential-thinking` |
| **librarian** | `websearch`, `context7` |
| **explorer** | *(none)* |
| **designer** | *(none)* |
| **fixer** | `memory` |

## Skills

Skills are loadable instruction sets that give agents specialised capabilities.

### agent-browser

**Available to:** designer (and orchestrator via `"skills": ["*"]`)

Browser automation for AI agents. Provides a CLI (`agent-browser`) for:
- Navigating URLs, taking snapshots with element refs
- Clicking, filling forms, selecting options
- Waiting for elements/network idle
- Screenshots, PDFs, video recording
- Session persistence and parallel sessions

**Workflow:** Navigate → Snapshot → Interact → Re-snapshot → Verify

**Location:** `/root/.agents/skills/agent-browser/`

### simplify

**Available to:** orchestrator (via `"skills": ["*"]`)

Post-editing code refinement. After writing code, this skill reviews and simplifies it for clarity without changing functionality:
- Reduces nesting and complexity
- Eliminates redundant code
- Improves naming
- Applies project-specific standards (from `CLAUDE.md` if present)
- Avoids nested ternaries — prefers `switch`/`if-else`

**Location:** `/root/.agents/skills/simplify/`

### cartography

**Available to:** orchestrator (via `"skills": ["*"]`)

Repository mapping and understanding. Generates hierarchical codemaps for unfamiliar codebases:
- Initialises with `cartographer.py init` — scans source files
- Detects changes via file hashing (`.slim/cartography.json`)
- Produces `codemap.md` files per directory + a root atlas
- Documents responsibility, design patterns, data flow, integration points

**Location:** `/root/.config/opencode/skills/cartography/`

## Permission Model

Defined in `opencode.json.template`. Controls what agents can do without asking.

### Tool Permissions

| Permission | Level |
|-----------|-------|
| `read`, `edit`, `glob`, `grep`, `list` | **allow** |
| `lsp`, `skill`, `task`, `todoread/write` | **allow** |
| `websearch`, `codesearch` | **allow** |
| `webfetch` | **ask** |
| `external_directory` | **ask** |
| `doom_loop` | **ask** |
| Everything else (`*`) | **ask** |

### File Read Restrictions

| Pattern | Level |
|---------|-------|
| `*` | allow |
| `*.env` | **deny** |
| `*.env.*` | **deny** |
| `*.env.example` | allow |

### Bash Command Permissions

**Allowed without asking:**
- Git read operations: `status`, `diff`, `log`, `branch`, `show`, `rev-parse`, `remote`, `stash list`
- Git write operations: `add`, `commit`, `checkout`, `switch`, `fetch`, `pull`, `merge`
- Package managers: `npm`, `npx`, `node`, `bun`, `pnpm`, `yarn`
- File utilities: `grep`, `rg`, `find`, `ls`, `cat`, `head`, `tail`, `wc`, `sort`, `uniq`, `diff`, `which`, `echo`, `pwd`, `env`
- File operations: `mkdir`, `cp`, `mv`, `touch`

**Ask first:**
- `git rebase`, `git push`, `git push --force-with-lease`
- `chmod`, `rm`
- `curl`, `wget`, `docker`
- `sh -c`, `bash -c`

**Denied:**
- `git push --force`, `git reset --hard`, `git clean`
- `rm -rf`
- `kill`, `killall`, `pkill`, `sudo`

## Presets

Three presets ship in `oh-my-opencode-slim.json.example`:

### default — Full quality

| Role | Model | Skills | MCPs |
|------|-------|--------|------|
| orchestrator | `claude-opus-4-6` | all | websearch, sequential-thinking, memory, time |
| oracle | `claude-opus-4-6` (high) | — | sequential-thinking |
| librarian | `claude-sonnet-4-6` (low) | — | websearch, context7 |
| explorer | `claude-haiku-4-5` (low) | — | — |
| designer | `claude-opus-4-6` (medium) | agent-browser | — |
| fixer | `claude-sonnet-4-6` (low) | — | memory |

### copilot — GitHub Copilot

All roles use `github-copilot/grok-code-fast-1` with the same skill/MCP assignments as default.

### budget — Cost-optimised

| Role | Model |
|------|-------|
| orchestrator | `claude-sonnet-4-6` |
| oracle | `claude-sonnet-4-6` |
| librarian | `claude-haiku-4-5` |
| explorer | `claude-haiku-4-5` |
| designer | `claude-sonnet-4-6` |
| fixer | `claude-haiku-4-5` |

## Fallback Chains

When a primary model is unavailable or exceeds `timeoutMs` (default 15s), models are tried in order:

| Role | Fallback sequence |
|------|------------------|
| orchestrator | Sonnet 4.6 → Sonnet 4.5 → GPT-5 → DeepSeek V3 |
| oracle | o3 → Sonnet 4.6 → DeepSeek R1 → GPT-5 |
| designer | Sonnet 4.6 → Opus 4.5 → Llama 4 Maverick → GPT-5 |
| explorer | Haiku 4.5 → GPT-4.1 Mini |
| librarian | Sonnet 4.5 → Llama 4 Scout → GPT-5 Mini |
| fixer | Sonnet 4.5 → GPT-5 Codex → DeepSeek R1 |

Disable with `"fallback": { "enabled": false }` in the plugin config.

## Custom Commands

62+ slash commands are mounted from `~/.config/opencode/commands/` into the container. These provide specialised agent personas and workflows:

| Category | Examples | Count |
|----------|----------|-------|
| **Agent personas** | `/bmad-agent-bmm-dev`, `/bmad-agent-bmm-architect`, `/bmad-agent-bmm-qa` | 13 |
| **Builder tools** | `/bmad-bmb-create-agent`, `/bmad-bmb-create-workflow`, `/bmad-bmb-validate-*` | 12 |
| **Project management** | `/bmad-bmm-create-prd`, `/bmad-bmm-sprint-planning`, `/bmad-bmm-code-review` | 23+ |
| **Creative workshops** | `/bmad-brainstorming`, `/bmad-cis-design-thinking`, `/bmad-cis-problem-solving` | 5+ |
| **Utilities** | `/bmad-help`, `/bmad-shard-doc`, `/bmad-editorial-review-*` | 7+ |

Commands load agent personas from `@_bmad/` reference files and present interactive menus.

## Customisation

Edit `~/.config/opencode/oh-my-opencode-slim.json` on the host. Changes take effect on next container start.

- **Switch preset:** Change `"preset": "budget"`
- **Swap a model:** Replace any `"model"` value (e.g. use GPT-5 for orchestrator)
- **Add MCP access:** Append server names to a role's `"mcps"` array
- **Grant skills:** Set `"skills": ["agent-browser"]` or `["*"]` for all
- **Disable fallback:** Set `"fallback": { "enabled": false }`
- **New preset:** Add a key under `"presets"` and set `"preset"` to its name
