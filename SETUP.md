# Setup Guide

Complete setup instructions for the AI News Briefing system, covering both the daily automated briefing and the on-demand custom topic briefing.

---

## Prerequisites

| Requirement | Used by | Details |
|---|---|---|
| **At least one AI CLI** | Both | Any of: **Claude Code** (`claude`), **Codex** (`codex`), **Gemini** (`gemini`), or **Copilot** (`copilot`). Multiple can be installed for fallback. |
| **Notion MCP** | Both (optional) | The Notion MCP server configured in your AI CLI's MCP settings |
| **Obsidian** | Both (optional) | [obsidian.md](https://obsidian.md) — local vault path set via `AI_BRIEFING_OBSIDIAN_VAULT` |
| **WebSearch tool** | Both | Built into most AI CLIs (no extra setup) |
| **Python 3.x** | Slack delivery | Required for `teams-to-slack.py` conversion |
| **GNU Make** | Optional | For `make run`, `make custom-brief`, etc. (`winget install GnuWin32.Make` on Windows) |

---

## 1. Install an AI CLI Engine

You need at least one of the following CLI engines. Install one or more for fallback support:

| Engine | Install | Verify |
|---|---|---|
| **Claude Code** | [code.claude.com](https://code.claude.com) | `claude --version` |
| **Codex** | `npm install -g @openai/codex` | `codex --version` |
| **Gemini** | `npm install -g @anthropic-ai/gemini-cli` or see [Google AI docs](https://ai.google.dev) | `gemini --version` |
| **Copilot** | `npm install -g @githubnext/github-copilot-cli` or via GitHub CLI extension | `copilot --version` |

The daily briefing auto-detects installed engines and falls back in order: `claude` → `codex` → `gemini` → `copilot`. Set `AI_BRIEFING_CLI` to force a specific engine:

```bash
export AI_BRIEFING_CLI=codex
```

---

## 2. Clone the Repository

```bash
git clone https://github.com/hoangsonww/AI-News-Briefing
cd AI-News-Briefing
```

Make scripts executable (macOS/Linux):

```bash
chmod +x briefing.sh custom-brief.sh scripts/*.sh
```

---

## 3. Configure Notion MCP

The system publishes briefings to a Notion database via the Notion MCP server.

### 3a. Add Notion MCP to Claude Code

In your Claude Code MCP settings, add the Notion server. This gives Claude access to your Notion workspace.

### 3b. Create or identify your database

The system expects a Notion database with at least these properties:

| Property | Type | Example |
|---|---|---|
| `Date` | Title | `2026-04-01 - AI Daily Briefing` |
| `Status` | Select or Text | `Complete` |
| `Topics` | Number | `9` |

### 3c. Find your data source ID

Ask Claude Code: *"List my Notion data sources"* or use the `notion-search` MCP tool. Copy the `data_source_id` for your target database.

The default data source ID is:

```
856794cc-d871-4a95-be2d-2a1600920a19
```

To use a different database, replace this ID in:
- `prompt.md` (daily briefing, Step 3)
- `prompt-custom-brief.md` (custom briefing, Phase 5)

---

## 4. Set Up Notifications (Optional)

### Microsoft Teams

1. Create a Power Automate webhook workflow for your Teams channel.
   Full guide: [NOTIFY_TEAMS.md](NOTIFY_TEAMS.md)

2. Set the webhook URL:

**macOS/Linux:**
```bash
export AI_BRIEFING_TEAMS_WEBHOOK="https://your-teams-webhook-url"
```

**Windows (persistent):**
```powershell
[Environment]::SetEnvironmentVariable("AI_BRIEFING_TEAMS_WEBHOOK", "https://your-teams-webhook-url", "User")
```

### Slack

1. Create an incoming webhook at [api.slack.com/apps](https://api.slack.com/apps).

2. Set the webhook URL:

**macOS/Linux:**
```bash
export AI_BRIEFING_SLACK_WEBHOOK="https://hooks.slack.com/services/T.../B.../..."
```

**Windows (persistent):**
```powershell
[Environment]::SetEnvironmentVariable("AI_BRIEFING_SLACK_WEBHOOK", "https://hooks.slack.com/services/T.../B.../...", "User")
```

### Multiple Webhooks

Separate multiple URLs with semicolons:

```bash
export AI_BRIEFING_TEAMS_WEBHOOK="https://webhook-1;https://webhook-2"
```

### Obsidian Vault

[Obsidian](https://obsidian.md) is a local-first markdown editor with a powerful graph view. Briefings published to Obsidian use `[[wikilinks]]` to create topic connections visible in the graph.

1. Install Obsidian and create or open a vault.

2. Set the vault path:

**macOS/Linux:**
```bash
export AI_BRIEFING_OBSIDIAN_VAULT="/path/to/your/vault"
```

**Windows (persistent):**
```powershell
[Environment]::SetEnvironmentVariable("AI_BRIEFING_OBSIDIAN_VAULT", "C:\path\to\your\vault", "User")
```

3. The system creates two subdirectories in your vault:
   - `AI-News-Briefings/` — daily and custom briefing pages
   - `Topics/` — stub pages for each topic (graph nodes)

4. Test connectivity:

```bash
bash scripts/test-obsidian.sh
```

5. Obsidian's graph view will show briefings connected to topic nodes. Open the graph view (`Ctrl/Cmd + G`) to visualize topic relationships across all your briefings.

---

## 5. Schedule the Daily Briefing

### macOS (launchd)

```bash
cp com.ainews.briefing.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.ainews.briefing.plist
launchctl list | grep ainews
```

### Windows (Task Scheduler)

```powershell
.\install-task.ps1              # Default: 8:00 AM
.\install-task.ps1 -Hour 7 -Minute 30  # Custom time
```

### Change schedule

```bash
# macOS: edit plist, then reload
launchctl unload ~/Library/LaunchAgents/com.ainews.briefing.plist
launchctl load ~/Library/LaunchAgents/com.ainews.briefing.plist

# Windows
.\install-task.ps1 -Hour 9 -Minute 0
```

---

## 6. Verify Setup

### Health check

```bash
bash scripts/health-check.sh
# or on Windows:
.\scripts\health-check.ps1
```

### Check installed engines

```bash
make info    # Shows all installed engines with ✓/✗ indicators
make check   # Verifies at least one AI CLI is available
```

### Test Notion connectivity

```bash
bash scripts/test-notion.sh
```

### Test Obsidian connectivity

```bash
bash scripts/test-obsidian.sh
```

### Manual test run

```bash
# Daily briefing
make run
# or: bash briefing.sh

# Custom brief
make custom-brief T="test topic"
# or: bash custom-brief.sh --topic "test topic"
```

---

## Quick Reference

```mermaid
flowchart TD
    subgraph "Setup Steps"
        S1[1. Install an AI CLI Engine] --> S2[2. Clone repo]
        S2 --> S3[3. Configure Notion MCP]
        S3 --> S4[4. Set webhook env vars]
        S4 --> S5[5. Install scheduler]
        S5 --> S6[6. Verify with health-check]
    end

    subgraph "Daily Use"
        S6 --> D1[Daily briefing runs at 8 AM]
        S6 --> D2["Custom brief: make custom-brief T=..."]
    end
```

| Task | Command |
|---|---|
| Run daily briefing | `make run` or `bash briefing.sh` |
| Run custom brief | `make custom-brief T="topic" NOTION=1` or `bash custom-brief.sh --topic "topic" --notion` |
| Run custom brief with Obsidian | `make custom-brief T="topic" OBSIDIAN=1` or `bash custom-brief.sh --topic "topic" --obsidian` |
| Check status | `make status` |
| View today's log | `make tail` |
| Test Notion connectivity | `bash scripts/test-notion.sh` |
| Test Obsidian connectivity | `bash scripts/test-obsidian.sh` |
| Test Teams delivery | `bash scripts/notify-teams.sh --all --card-file logs/YYYY-MM-DD-card.json` |
| Test Slack delivery | `bash scripts/notify-slack.sh --all --card-file logs/YYYY-MM-DD-card.json` |
