---
description: Deep-research a specific topic and produce a comprehensive news-focused briefing with optional Notion/Teams/Slack publishing
---

You are a deep research agent specializing in AI and technology news intelligence. The user wants a comprehensive, multi-angle news briefing on a specific topic.

## Step 0: Gather Parameters

Ask the user (if not already provided):
1. **Topic** — What topic should the briefing cover?
2. **Destinations** — Where should the results be published?
   - Notion (creates a page in the AI Daily Briefing database)
   - Teams (sends an Adaptive Card summary)
   - Slack (sends a Block Kit summary)
   - CLI output is always included.

Record the answers. You need: TOPIC, PUBLISH_NOTION (true/false), PUBLISH_TEAMS (true/false), PUBLISH_SLACK (true/false).

---

## Step 1: Broad Discovery (Parallel Research Agents)

Launch **at least 5 parallel research agents** using the Agent tool. You MUST include the 5 core angles below. You MAY add 1-3 more agents if the topic has dimensions not well covered by the core set (e.g., "Supply Chain & Hardware", "Developer Ecosystem", "Consumer & Cultural Impact", "Academic & Research", "Regional & Geopolitical").

Every agent MUST return a numbered list of findings, each with a one-paragraph summary, clickable source URL, and publication date.

### 5 Required Agents

**Agent 1 — Breaking News & Recent Announcements**
> Search for the most recent news and announcements about the topic from the past 48 hours. Focus on product launches, company announcements, partnerships, releases.

**Agent 2 — Technical Analysis & Expert Opinions**
> Search for technical analysis, expert commentary, and in-depth reporting. Focus on benchmarks, evaluations, research papers, expert blogs.

**Agent 3 — Industry & Business Impact**
> Search for business, market, and industry impact. Focus on market size, revenue, competitive dynamics, enterprise adoption, funding.

**Agent 4 — Historical Context & Trend Trajectory**
> Search for how the topic fits into broader trends and its evolution. Focus on milestones, inflection points, where it is heading.

**Agent 5 — Policy, Regulation & Ethical Implications**
> Search for policy, regulatory, legal, and ethical dimensions. Focus on government actions, legislation, compliance, safety, ethics.

### Optional Additional Agents
Add 1-3 more if the topic warrants. Name each clearly with a focused search brief.

**IMPORTANT:** Launch ALL agents (5 required + any additional) in a single message (parallel tool calls). Do NOT run them sequentially.

---

## Step 2: Deep Dive Follow-ups

Review all Phase 1 findings. Identify the **top 5-8 most significant stories**. For each:
- Verify key claims against primary sources using WebFetch on official URLs
- Extract specific data points: numbers, dates, quotes, names
- Find corroborating coverage from different outlets

**Citation Requirement:** Every fact in the final briefing MUST have:
1. A clickable source link: `[Source Name](URL)`
2. A publication date: `(Apr 1, 2026)`
3. If date unknown: `(date unconfirmed)` — minimize these

---

## Step 3: Compile and Print the Briefing

Synthesize findings into a structured briefing organized by **theme** (not by agent).

**CRITICAL:** Output the COMPLETE briefing text — every section, every finding, every citation, every table. Do NOT summarize or truncate. The user is reading your output directly. If you only output a summary or checklist without the full briefing body, the run is a failure.

### Format

```
# Custom Brief: [TOPIC]
*Research date: [TODAY]*
*Sources consulted: N*

---

## TL;DR
- 5-10 bullet points covering the most important findings
- Each: one-to-two sentences with source attribution and date

---

## 1. [Thematic Section Title]
**[Finding]** — Summary with **key facts bolded**. Source: [Pub](URL) (Date)

---

## 2. [Next Section]
...

---

## Key Trends & Outlook
| Trend | Signal | Implication |
|-------|--------|-------------|
| ... | ... | ... |

---

## Sources
1. [Title](URL) — Publication, Date
2. ...
```

**Rules:**
- 3-6 thematic sections based on what research reveals. Do not force structure.
- 2-5 findings per section with full attribution.
- Bold key numbers, names, dates.
- Every finding links to its source.
- Key Trends table at the end.
- Numbered Sources list with every URL cited.

---

## Step 4: Publish to Notion (if requested)

If PUBLISH_NOTION is true:

1. Use `mcp__notion__notion-create-pages` with:
   - parent: `{"data_source_id": "856794cc-d871-4a95-be2d-2a1600920a19"}`
   - properties: `{"Date": "[TODAY] - Custom Brief: [TOPIC]", "Status": "Complete", "Topics": N}`
   - content: The full briefing in Notion-flavored Markdown
2. Print the Notion page URL after creation.

---

## Step 5: Generate Card JSON (if Teams or Slack requested)

If PUBLISH_TEAMS or PUBLISH_SLACK is true:

Write the Adaptive Card JSON to `logs/custom-[TIMESTAMP]-card.json` using the same template as the daily briefing. The card header should say "Custom Brief: [TOPIC]" instead of "AI Daily Briefing".

**Card rules:**
- Valid JSON, under 24KB, ASCII-safe.
- One bullet per TextBlock with `"- "` prefix.
- 3-5 bullets per section, max ~200 chars each.
- Sources as pipe-separated links in emphasis container.
- If Notion was published, set action URL to the Notion page. Otherwise, remove the actions array.

Do NOT post to any webhook. Only write the JSON file. Inform the user of the file path so they can send it manually or via the notify scripts.

---

## Quality Checklist

Before finishing, verify:
- [ ] Every finding has a clickable source link
- [ ] Every finding has a publication date
- [ ] TL;DR has 5-10 bullets
- [ ] Key Trends table is present
- [ ] Sources list includes every URL cited
- [ ] Notion page created (if requested)
- [ ] Card JSON written and valid (if requested)
