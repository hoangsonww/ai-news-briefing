# AI News Briefing

Automated daily AI news research agent that searches the web, compiles a structured briefing, and publishes it to Notion -- powered by Claude Code CLI. Supports both macOS (launchd) and Windows (Task Scheduler).

## Overview

AI News Briefing is a fully automated pipeline that runs every morning on your machine. It uses Claude Code in headless mode to act as a news research agent: searching the web across 9 AI-related topics, compiling the results into a two-tier briefing (TL;DR + full report), and writing the finished page directly to a Notion database.

The entire process -- from triggering to publishing -- requires zero human intervention. You wake up, open Notion, and your daily AI briefing is already there.

### Why it exists

Keeping up with AI news across models, tools, policy, funding, and open source is a full-time job. This project compresses that into an automated daily digest that covers 9 topic areas in a consistent format, delivered to your Notion workspace before you start your workday.

## Architecture

```mermaid
flowchart TD
    subgraph Schedulers
        A1[macOS launchd]
        A2[Windows Task Scheduler]
    end

    A1 -->|8:00 AM daily| B1[briefing.sh]
    A2 -->|8:00 AM daily| B2[briefing.ps1]

    B1 -->|Reads| C[prompt.md]
    B2 -->|Reads| C

    B1 -->|Invokes| D[Claude Code CLI]
    B2 -->|Invokes| D

    D -->|Step 1: Search| E[WebSearch Tool]
    E -->|9 topics x multiple queries| F[Web Results]
    F -->|Step 2: Compile| G[Two-Tier Briefing]
    G -->|Step 3: Write| H[Notion MCP]
    H -->|Creates page| I[Notion Database]

    B1 -->|Logs output| J[logs/YYYY-MM-DD.log]
    B2 -->|Logs output| J
    J -->|Auto-cleanup| K[Delete logs older than 30 days]
```

**Data flow summary:**

1. The platform scheduler fires the entry point script (`briefing.sh` on macOS, `briefing.ps1` on Windows) at the configured time each day.
2. The script reads the prompt from `prompt.md` and passes it to the Claude Code CLI in print mode.
3. Claude Code executes the prompt as an agentic task -- performing web searches, compiling results, and calling the Notion MCP tool.
4. Notion receives the finished briefing as a new database page.
5. Logs are written to a date-stamped file and automatically pruned after 30 days.

## Prerequisites

| Requirement | Details |
|---|---|
| **OS** | macOS or Windows 10/11 |
| **Claude Code CLI** | Installed at `~/.local/bin/claude` with a valid Anthropic API key or Max subscription |
| **Notion MCP** | The Notion MCP server must be configured in Claude Code's MCP settings with access to your workspace |
| **WebSearch tool** | Available by default in Claude Code (no extra setup needed) |

## Installation

### 1. Clone the project

```bash
git clone <your-repo-url> ~/ai-news-briefing
cd ~/ai-news-briefing
```

### 2. Platform-specific setup

#### macOS (launchd)

```bash
# Make the shell script executable
chmod +x ~/ai-news-briefing/briefing.sh

# Install the launchd plist
cp ~/ai-news-briefing/com.ainews.briefing.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.ainews.briefing.plist

# Verify the agent is registered
launchctl list | grep ainews
```

Optionally, set up the manual trigger command:

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/ai-news << 'EOF'
#!/bin/bash
echo "Starting AI News Briefing..."
launchctl kickstart "gui/$(id -u)/com.ainews.briefing"
echo "Running. Check Notion or: tail -f ~/ai-news-briefing/logs/$(date +%Y-%m-%d).log"
EOF
chmod +x ~/.local/bin/ai-news
```

Make sure `~/.local/bin` is in your `PATH` (add `export PATH="$HOME/.local/bin:$PATH"` to your `~/.zshrc` if needed).

#### Windows (Task Scheduler)

Open PowerShell and run the installer script:

```powershell
cd $env:USERPROFILE\ai-news-briefing
.\install-task.ps1
```

This registers a Task Scheduler task named `AiNewsBriefing` that runs daily at 8:00 AM under the current user account.

To customize the time:

```powershell
.\install-task.ps1 -Hour 7 -Minute 30
```

## Configuration

### Change the schedule

**macOS:** Edit `com.ainews.briefing.plist` and modify the `StartCalendarInterval` section, then reload:

```bash
launchctl unload ~/Library/LaunchAgents/com.ainews.briefing.plist
launchctl load ~/Library/LaunchAgents/com.ainews.briefing.plist
```

**Windows:** Re-run the installer with new time parameters:

```powershell
.\install-task.ps1 -Hour 9 -Minute 0
```

### Change the model

Edit the entry point script for your platform:

- **macOS:** `briefing.sh` -- change the `--model sonnet` flag
- **Windows:** `briefing.ps1` -- change the `--model sonnet` argument

**Model trade-offs:**

| Model | Speed | Cost | Quality |
|---|---|---|---|
| `haiku` | Fastest | Lowest | Good for basic summaries |
| `sonnet` | Balanced | Moderate | Recommended default |
| `opus` | Slowest | Highest | Best for deep analysis |

### Change the budget cap

Edit the `--max-budget-usd` value in `briefing.sh` (macOS) or `briefing.ps1` (Windows). The default is `2.00` (USD per run). This acts as a safety cap -- if the agent's token usage would exceed this amount, the run stops.

### Change the topics

Edit `prompt.md` and modify the "Topics to Search" list. You can add, remove, or rename topics. If you change the number of topics, also update the `"Topics": 9` value in the Notion properties section at the bottom of the prompt.

## Usage

### Automatic (scheduled)

Once installed, the briefing runs automatically every day at the scheduled time (default: 8:00 AM). No action needed.

### Manual trigger

**macOS:**

```bash
ai-news
# or: launchctl kickstart "gui/$(id -u)/com.ainews.briefing"
```

**Windows (PowerShell or cmd):**

```powershell
schtasks /run /tn AiNewsBriefing
```

### Watch the progress

**macOS:**

```bash
tail -f ~/ai-news-briefing/logs/$(date +%Y-%m-%d).log
```

**Windows:**

```powershell
Get-Content "$env:USERPROFILE\ai-news-briefing\logs\$(Get-Date -Format 'yyyy-MM-dd').log" -Wait
```

A typical successful run takes 2-4 minutes and ends with a message like:

```
2026-03-09 14:08:08 Briefing complete. Check Notion for today's report.
```

## Notion Setup

### Database schema

The prompt expects a Notion database with at least these properties:

| Property | Type | Example Value |
|---|---|---|
| `Date` | Title | `2026-03-09 - AI Daily Briefing` |
| `Status` | Select or Text | `Complete` |
| `Topics` | Number | `9` |

You can add additional properties to the database (tags, priority, etc.), but the three above are what the agent writes to.

### Data source ID

The prompt references a specific Notion data source ID:

```
856794cc-d871-4a95-be2d-2a1600920a19
```

To use your own database, replace this value in `prompt.md` (in the Step 3 section). To find your data source ID:

1. Open Claude Code and ensure the Notion MCP is connected.
2. Ask Claude: "List my Notion data sources" or use the `notion-search` MCP tool.
3. Copy the `data_source_id` for the database you want to use.
4. Replace the ID in `prompt.md`.

### Page format

Each generated page contains:

- **TL;DR** -- 10-15 bullet points covering the biggest stories (roughly a 1-minute read)
- **Divider**
- **Full Briefing** -- 9 sections (one per topic), each with 3-8 detailed bullet points and source attribution
- **Key Takeaways table** -- a summary table of major trends and signals

## How the Prompt Works

The prompt (`prompt.md`) instructs Claude to execute three sequential steps within a single agentic session:

### Step 1: Search for News

Claude uses the WebSearch tool to perform multiple searches per topic, targeting news from the past 24-48 hours. The search strategy includes date-qualified queries like `"[topic] news today 2026-03-09"` and company-specific queries.

### Step 2: Compile the Briefing

Search results are synthesized into a two-tier format:

- **Tier 1 (TL;DR):** 10-15 one-sentence bullet points covering the top stories across all topics. Designed as a quick-scan summary.
- **Tier 2 (Full Briefing):** 9 sections with detailed coverage, source attribution, and a closing Key Takeaways table.

### Step 3: Write to Notion

Claude calls the `mcp__notion__notion-create-pages` tool to create a new page in the target database with the compiled briefing as Notion-flavored Markdown content.

## Topic Coverage

| # | Topic | What It Covers |
|---|---|---|
| 1 | Claude Code / Anthropic | New features, releases, Anthropic announcements, blog posts |
| 2 | OpenAI / Codex / ChatGPT | Model updates, Codex features, ChatGPT capabilities, API changes |
| 3 | AI Coding IDEs | Cursor, Windsurf, GitHub Copilot, Xcode AI, JetBrains AI, Google Antigravity |
| 4 | Agentic AI Ecosystem | Agent frameworks (LangChain, CrewAI, AutoGen), MCP updates, new agent products |
| 5 | AI Industry | New model releases, benchmarks, major company announcements |
| 6 | Open Source AI | Llama, Mistral, DeepSeek, Hugging Face, open-weight model releases |
| 7 | AI Startups & Funding | Funding rounds, acquisitions, notable startup launches |
| 8 | AI Policy & Regulation | Government policy, EU AI Act, state laws, AI safety developments |
| 9 | Dev Tools & Frameworks | Vercel, Next.js, React Native, TypeScript, AI-related developer tooling |

## Logs

### Location

All logs are stored in the `logs/` directory within the project:

| File | Contents |
|---|---|
| `YYYY-MM-DD.log` | Full output from each run (timestamps, Claude output, success/failure) |
| `launchd-stdout.log` | (macOS only) Standard output captured by launchd |
| `launchd-stderr.log` | (macOS only) Standard error captured by launchd |

### Reading logs

**macOS:**

```bash
cat ~/ai-news-briefing/logs/$(date +%Y-%m-%d).log
tail -f ~/ai-news-briefing/logs/$(date +%Y-%m-%d).log
```

**Windows:**

```powershell
Get-Content "$env:USERPROFILE\ai-news-briefing\logs\$(Get-Date -Format 'yyyy-MM-dd').log"
Get-Content "$env:USERPROFILE\ai-news-briefing\logs\$(Get-Date -Format 'yyyy-MM-dd').log" -Wait
```

### Auto-cleanup

Logs older than 30 days are automatically deleted at the end of each run on both platforms. The macOS-specific `launchd-stdout.log` and `launchd-stderr.log` files are not date-stamped and may need periodic manual cleanup.

## Troubleshooting

### "Claude Code cannot be launched inside another Claude Code session"

This error occurs when the `CLAUDECODE` environment variable is set, which happens if you trigger the script from inside a Claude Code terminal session. Both `briefing.sh` and `briefing.ps1` unset this variable automatically, but if you see this error:

- Make sure you are running the briefing from a regular terminal, not from within Claude Code.
- Verify the entry point script contains the `unset CLAUDECODE` / `$env:CLAUDECODE = $null` line.

### Scheduled task does not run at the expected time

**macOS (launchd):**

- **Mac was asleep:** launchd will run the job when the Mac wakes up if the scheduled time was missed. If Power Nap is disabled or the lid was closed, the job may not fire until the next login.
- **Powered off at scheduled time:** The job is skipped entirely for that day.
- **Agent not loaded:** Verify with `launchctl list | grep ainews`. If missing, reload the plist.
- **Path issues:** The plist sets a custom `PATH` and `HOME`. If Claude is installed in a non-standard location, update the `PATH` in the plist.

**Windows (Task Scheduler):**

- **Machine was off/asleep:** `StartWhenAvailable` is enabled, so the task runs as soon as the machine wakes or the user logs in.
- **Task not registered:** Verify with `schtasks /query /tn AiNewsBriefing`. If missing, re-run `install-task.ps1`.
- **Execution policy:** The task action uses `-ExecutionPolicy Bypass`. If this is overridden by group policy, contact your IT admin or run `briefing.ps1` manually.

### Run succeeds but no Notion page appears

- Check that the Notion MCP is configured in Claude Code's MCP settings.
- Verify the data source ID in `prompt.md` matches a database your Notion integration has access to.
- Look at the log output -- Claude typically prints a Notion URL on success.

### Budget exceeded

If the log shows the run stopped mid-way, the `--max-budget-usd` cap may have been reached. Increase the budget in the entry point script or switch to a cheaper model.

### Multiple runs in the same day

Running the briefing multiple times in a day creates multiple Notion pages (one per run). Logs append to the same date-stamped file, so all runs for a given day are captured in one log.

## Cost Estimate

With the default configuration (`sonnet` model, 9 topics, `$2.00` budget cap):

| Component | Estimated Cost per Run |
|---|---|
| Input tokens (prompt + search results) | ~$0.30-0.60 |
| Output tokens (briefing + tool calls) | ~$0.20-0.40 |
| WebSearch tool calls (~15-25 searches) | ~$0.15-0.40 |
| **Total per run** | **~$0.70-1.40** |
| **Monthly (daily runs)** | **~$21-42** |

Actual costs vary based on the volume of news, number of search queries, and briefing length. The `--max-budget-usd 2.00` cap ensures no single run exceeds $2.00.

## Project Structure

```
ai-news-briefing/
├── briefing.sh                  # macOS entry point (bash)
├── briefing.ps1                 # Windows entry point (PowerShell)
├── prompt.md                    # Agent prompt (shared across platforms)
├── com.ainews.briefing.plist    # macOS launchd schedule definition
├── install-task.ps1             # Windows Task Scheduler installer
├── logs/                        # Run logs (git-ignored)
│   ├── YYYY-MM-DD.log           # Per-day output logs
│   ├── launchd-stdout.log       # (macOS) launchd stdout capture
│   └── launchd-stderr.log       # (macOS) launchd stderr capture
├── .gitignore
├── ARCHITECTURE.md              # Detailed architecture documentation
└── README.md                    # This file
```
