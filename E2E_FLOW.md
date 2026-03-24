# End-to-End Flow: AI News Briefing Pipeline

This document describes the real runtime flow of this repository as of March 24, 2026.
It is based on the current implementation in:

- `briefing.sh`
- `briefing.ps1`
- `prompt.md`
- `scripts/notify-teams.sh`
- `scripts/notify-teams.ps1`
- `scripts/notify-slack.sh`
- `scripts/notify-slack.ps1`
- `scripts/teams-to-slack.py`
- `scripts/build-teams-card.py` (legacy reference)
- `Makefile`

---

## 1. System Topology

```mermaid
flowchart TD
    subgraph Triggers
        A1[macOS launchd\ncom.ainews.briefing.plist]
        A2[Windows Task Scheduler\nAiNewsBriefing]
        A3[Manual: make run / run-bg / run-scheduled]
        A4[Manual direct: briefing.sh or briefing.ps1]
    end

    A1 --> B1[briefing.sh]
    A2 --> B2[briefing.ps1]
    A3 --> B1
    A3 --> B2
    A4 --> B1
    A4 --> B2

    B1 --> C[prompt.md loaded into memory]
    B2 --> C

    C --> D[Claude Code CLI\n-p --model opus\n--dangerously-skip-permissions]

    D --> E[WebSearch tool calls]
    D --> F[Notion MCP calls]

    F --> G[Notion page created\nDate + Status + Topics]

    D --> H[logs/YYYY-MM-DD.log\nstdout + stderr appended]
    D --> I[Expected Teams artifact\nlogs/YYYY-MM-DD-card.json]

    B1 --> J{AI_BRIEFING_TEAMS_WEBHOOK set?}
    B2 --> J
    J -->|No| K[Skip Teams notify]
    J -->|Yes| L[notify-teams.sh / notify-teams.ps1]
    L --> M{card.json exists\nand valid JSON?}
    M -->|No| N[Teams notify fails\nrun still completed]
    M -->|Yes| O[POST card JSON to Teams webhooks]
    O --> P[Teams channel card]

    B1 --> R{AI_BRIEFING_SLACK_WEBHOOK set?}
    B2 --> R
    R -->|No| S[Skip Slack notify]
    R -->|Yes| T[notify-slack.sh / notify-slack.ps1]
    T --> U{card.json exists\nand conversion valid?}
    U -->|No| V[Slack notify fails\nrun still completed]
    U -->|Yes| W[Convert + POST to Slack webhooks]
    W --> X[Slack channel message]

    B1 --> Q[Delete *.log older than 30 days]
    B2 --> Q
```

---

## 2. Runtime Sequence (Successful Path)

```mermaid
sequenceDiagram
    participant S as Scheduler/Manual Trigger
    participant E as Entry Script
    participant C as Claude CLI
    participant W as WebSearch
    participant N as Notion MCP
    participant L as logs/YYYY-MM-DD.log
    participant CF as logs/YYYY-MM-DD-card.json
    participant T as notify-teams
    participant TW as Teams Webhook(s)
    participant S2 as notify-slack
    participant SW as Slack Webhook(s)

    S->>E: Start briefing.sh or briefing.ps1
    E->>E: Resolve dirs and date
    E->>E: Clear CLAUDECODE env var
    E->>E: Ensure logs/ exists
    E->>E: Load prompt.md

    E->>C: Run Claude with prompt text
    C->>W: Search news by topic
    W-->>C: Recent results
    C->>N: Create Notion page
    N-->>C: Notion URL / success

    C-->>L: Append run output
    C-->>CF: Write Adaptive Card JSON (expected)
    E->>E: Record success in log

    E->>T: Call notify-teams (if Teams webhook env var set)
    T->>CF: Read + validate JSON
    T->>TW: POST payload as-is
    TW-->>T: 2xx
    T-->>E: success

    E->>S2: Call notify-slack (if Slack webhook env var set)
    S2->>CF: Read card JSON
    S2->>S2: Convert to Block Kit via teams-to-slack.py
    S2->>SW: POST converted payload
    SW-->>S2: 2xx
    S2-->>E: success

    E->>E: Cleanup logs older than 30 days
```

---

## 3. Stage-by-Stage Contracts

### Stage A: Trigger and Entry

| Area | macOS path | Windows path |
|---|---|---|
| Scheduler | `com.ainews.briefing.plist` | Task `AiNewsBriefing` via `install-task.ps1` |
| Entry script | `briefing.sh` | `briefing.ps1` |
| Default schedule | 08:00 daily | 08:00 daily |
| Manual trigger | `make run`, `make run-bg`, `make run-scheduled` | same Make targets, or `schtasks /run /tn AiNewsBriefing` |

Entry scripts do the same core setup:

1. Compute `DATE`, `LOG_DIR`, `LOG_FILE`.
2. Clear `CLAUDECODE` to avoid nested-session failures.
3. Create `logs/` if missing.
4. Read `prompt.md` as one string.
5. Invoke Claude CLI with the configured model (`opus` in current scripts).
6. Append output to `logs/YYYY-MM-DD.log`.
7. Attempt Teams notify when Teams webhook env var is present.
8. Attempt Slack notify when Slack webhook env var is present.
9. Delete only old `*.log` files (>30 days).

### Stage B: Date Override / Backfill Path

Both entry scripts support backfill:

- Bash: `briefing.sh YYYY-MM-DD`
- PowerShell: `briefing.ps1 -BriefingDate YYYY-MM-DD`
- Make wrapper: `make run D=YYYY-MM-DD`

When date override is used, scripts prepend a runtime instruction block to the prompt:

- Search relative to override date, not current day.
- Use override date in Notion title.
- Use override date in card filename (`logs/<date>-card.json`).

### Stage C: AI Execution Logic

`prompt.md` defines the internal flow:

1. Step 0a: load `logs/covered-stories.txt` for deduplication.
2. Step 0b: search Notion for existing "AI Daily Briefing" pages. If today's page exists, record its page ID (`PAGE_EXISTS = true`). Read the most recent page for additional dedup context.
3. Step 1: search 9 topic areas for past-24-hour updates. Check official changelogs.
4. Step 2: compile TL;DR + full briefing sections with dates.
5. Step 3: if `PAGE_EXISTS = true`, update the existing Notion page. Otherwise, create a new page. This prevents duplicate pages on re-runs.
6. Step 4: write Adaptive Card JSON to `logs/YYYY-MM-DD-card.json`.
7. Step 5: append today's headlines to `logs/covered-stories.txt`.

### Stage D: Teams & Slack Delivery

**Teams** notifier scripts are intentionally thin:

- Find card file (default `logs/<today>-card.json`, or passed `--card-file` / `-CardFile`).
- Validate JSON (`python3 -m json.tool` on shell, `ConvertFrom-Json` on PowerShell).
- Resolve target URLs from `AI_BRIEFING_TEAMS_WEBHOOK` (semicolon-separated). By default only the first URL is used; pass `--all` / `-All` to post to all.
- POST payload directly to webhooks.

**Slack** notifier scripts follow the same pattern but add a conversion step:

- Read the Teams card JSON file.
- Convert to Slack Block Kit format using `scripts/teams-to-slack.py` (pure Python stdlib, no external deps).
- Resolve target URLs from `AI_BRIEFING_SLACK_WEBHOOK` (same semicolon / `--all` pattern).
- POST converted payload to webhooks.

Neither builds cards from logs. Both are resilient to individual webhook failures.

---

## 4. Notification Decision Graph (Teams + Slack)

```mermaid
flowchart TD
    A[Entry script success] --> B{Teams webhook env set?}
    A --> C{Slack webhook env set?}

    B -->|No| D[Skip Teams step]
    B -->|Yes| E[Call notify-teams]
    E --> F{Card file exists and JSON valid?}
    F -->|No| G[Teams notify failed]
    F -->|Yes| H[POST to Teams webhooks]
    H --> I{Any HTTP 2xx?}
    I -->|No| J[Teams notify failed]
    I -->|Yes| K[Teams notify success]

    C -->|No| L[Skip Slack step]
    C -->|Yes| M[Call notify-slack]
    M --> N{Card file exists and conversion valid?}
    N -->|No| O[Slack notify failed]
    N -->|Yes| P[POST to Slack webhooks]
    P --> Q{Any HTTP 2xx?}
    Q -->|No| R[Slack notify failed]
    Q -->|Yes| S[Slack notify success]
```

---

## 5. Alignment Status

The prompt and runtime pipeline are aligned on a shared card artifact and dual-channel notify paths:

| Component | Behavior |
|---|---|
| `prompt.md` Step 4 | AI writes `logs/YYYY-MM-DD-card.json` directly |
| `scripts/notify-teams.sh/.ps1` | Validates and POSTs the prebuilt card JSON |
| `scripts/notify-slack.sh/.ps1` | Converts prebuilt card JSON to Block Kit and POSTs it |
| `scripts/teams-to-slack.py` | Conversion layer from Teams Adaptive Card schema to Slack Block Kit |
| `scripts/build-teams-card.py` | Legacy parser, not called by any active script |

Additionally, `prompt.md` Step 3 now prevents duplicate Notion pages by checking for an existing page during Step 0b and updating rather than creating when one is found.
Current `briefing.sh` and `briefing.ps1` invoke both notifiers in all-URL mode (`--all` / `-All`) when the corresponding env vars are set.

---

## 6. Failure-State Diagram

```mermaid
stateDiagram-v2
    [*] --> Triggered
    Triggered --> Setup
    Setup --> ClaudeRun

    ClaudeRun --> ClaudeFailed: non-zero exit / runtime error
    ClaudeRun --> ClaudeSucceeded: exit 0

    ClaudeSucceeded --> TeamsCheck
    TeamsCheck --> TeamsSkipped: teams env not set
    TeamsCheck --> TeamsNotifyAttempt: teams env set
    TeamsNotifyAttempt --> TeamsFailed: missing card / invalid json / non-2xx
    TeamsNotifyAttempt --> TeamsDone: teams notify success

    TeamsSkipped --> SlackCheck
    TeamsFailed --> SlackCheck
    TeamsDone --> SlackCheck

    SlackCheck --> SlackSkipped: slack env not set
    SlackCheck --> SlackNotifyAttempt: slack env set
    SlackNotifyAttempt --> SlackFailed: missing card / conversion error / non-2xx
    SlackNotifyAttempt --> SlackDone: slack notify success

    ClaudeFailed --> Cleanup
    SlackSkipped --> Cleanup
    SlackFailed --> Cleanup
    SlackDone --> Cleanup

    Cleanup --> [*]
```

Notes:

- Teams and Slack notification failures do not currently mark the whole run as failed at the script level.
- Log cleanup only targets `*.log`; old `*-card.json` files are not rotated by current scripts.

---

## 7. Artifacts and Ownership

| Artifact | Producer | Consumer | Required for success |
|---|---|---|---|
| `logs/YYYY-MM-DD.log` | entry scripts + Claude stdout/stderr | humans, diagnostic scripts | No (diagnostic) |
| Notion page | Claude via Notion MCP | Notion workspace | Yes |
| `logs/YYYY-MM-DD-card.json` | Claude (expected) | notify-teams scripts, notify-slack scripts, teams-to-slack.py | Yes for Teams and Slack paths |
| Converted Slack payload (temp) | notify-slack scripts | Slack webhook endpoint | Yes for Slack path |
| Teams message | notify-teams scripts | Teams channel | Optional |
| Slack message | notify-slack scripts | Slack channel | Optional |

---

## 8. Operational Checklist

1. Ensure Claude CLI path exists (`~/.local/bin/claude` or `.exe`).
2. Ensure Notion MCP is configured and has DB access.
3. Ensure `prompt.md` Step 4 still writes `logs/YYYY-MM-DD-card.json`.
4. If Teams is enabled, verify `AI_BRIEFING_TEAMS_WEBHOOK` and direct `notify-teams` test.
5. If Slack is enabled, verify `AI_BRIEFING_SLACK_WEBHOOK`, Python availability, and direct `notify-slack` test.
6. Use `make tail` / `make log` to inspect run outcomes.

---

## 9. Recent Changes

- **Duplicate Notion page prevention:** Step 0b now captures `PAGE_EXISTS` and the page ID. Step 3 updates the existing page when one is found, and only creates a new page otherwise. The agent no longer re-queries Notion in Step 3.
- **Multiple webhook support:** Both `AI_BRIEFING_TEAMS_WEBHOOK` and `AI_BRIEFING_SLACK_WEBHOOK` accept semicolon-separated URLs. By default only the first URL is used. Pass `--all` (bash) or `-All` (PowerShell) to post to all configured URLs.
- **Slack integration:** `notify-slack.sh/.ps1` converts the Teams card JSON to Slack Block Kit format using `teams-to-slack.py` and POSTs it to Slack webhooks. No separate card generation needed — reuses the Teams card.
- **Prompt/runtime alignment:** `prompt.md` Step 4 now writes `logs/YYYY-MM-DD-card.json` directly. The legacy `build-teams-card.py` parser is no longer part of the active pipeline.
