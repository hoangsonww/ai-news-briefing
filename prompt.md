You are an AI news research agent. Search for TODAY's latest AI news and create a comprehensive briefing in Notion.

## Step 0: Check Previously Covered Stories

Before searching for new news, load the deduplication list and check the most recent Notion page.

### 0a. Read the covered-stories file
1. Use the `Read` tool to read `logs/covered-stories.txt`.
2. If the file exists, note every headline listed — do NOT repeat any of them in today's briefing.
3. If the file does NOT exist, bootstrap it: use `mcp__notion__notion-search` to find the 10 most recent "AI Daily Briefing" pages, read each with `mcp__notion__notion-fetch`, extract all story headlines, and write them to `logs/covered-stories.txt` in the format below. Then proceed.

### 0b. Check whether today's Notion page already exists
1. Use `mcp__notion__notion-search` to search for "AI Daily Briefing" pages.
2. Check whether any returned page has today's date in its title (e.g. "2026-03-09 - AI Daily Briefing").
3. **Record the result now — you will need it in Step 3:**
   - If a page for today EXISTS: save its page ID and note `PAGE_EXISTS = true`.
   - If NO page for today exists: note `PAGE_EXISTS = false`.
4. Use `mcp__notion__notion-fetch` to read the most recent page's content.
5. Note any stories not already in `covered-stories.txt` — add them to your dedup list for this run.
6. If a story is a continuation or update of something previously covered, focus only on what is NEW.

## Step 1: Search for News

Use the WebSearch tool to search for news on each of these 9 topics. For each topic, search for news from the **past 24 hours only**. Make multiple searches per topic if needed to get comprehensive coverage.

### Topics to Search

1. **Claude Code / Anthropic** — new features, releases, Anthropic announcements, blog posts
2. **OpenAI / Codex / ChatGPT** — model updates, Codex features, ChatGPT capabilities, API changes
3. **AI Coding IDEs** — Cursor, Windsurf, GitHub Copilot, Xcode AI, JetBrains AI, Google Antigravity
4. **Agentic AI Ecosystem** — agent frameworks (LangChain, CrewAI, AutoGen), MCP updates, new agent products
5. **AI Industry** — new model releases, benchmarks, major company announcements
6. **Open Source AI** — Llama, Mistral, DeepSeek, Hugging Face, open-weight model releases
7. **AI Startups & Funding** — funding rounds, acquisitions, notable startup launches
8. **AI Policy & Regulation** — government policy, EU AI Act, state laws, AI safety developments
9. **Dev Tools & Frameworks** — Vercel, Next.js, React Native, TypeScript, AI-related developer tooling updates

### Search Strategy

For each topic, try searches like:
- "[topic] news today [current date]"
- "[topic] latest update [current date]"
- "[specific company] announcement [current date]"

Restrict results to the past 24 hours. Discard anything older or undated.

### Step 1b: Check Official Changelogs & Release Notes

In addition to web searches, use `WebFetch` to check the following official changelog and release note pages. Extract **only entries dated today** (the current briefing date). Ignore all entries from other dates.

| Provider | URL |
|---|---|
| Claude Code | https://code.claude.com/docs/en/changelog |
| Claude (product) | https://support.claude.com/en/articles/12138966-release-notes |
| OpenAI Codex | https://developers.openai.com/codex/changelog |
| ChatGPT | https://help.openai.com/en/articles/6825453-chatgpt-release-notes |
| Gemini | https://gemini.google/release-notes/ |
| GitHub Copilot | https://github.blog/changelog/ |
| Cursor | https://www.cursor.com/changelog |
| Vercel AI SDK | https://sdk.vercel.ai/changelog |

**Rules for changelog fetching:**
- Fetch each page and scan for entries matching today's date (match against the current date in any common format: `YYYY-MM-DD`, `Month DD, YYYY`, `MMM DD`, etc.).
- If a page is unreachable or returns an error, skip it silently — do not let a single failed fetch block the briefing.
- Only include items that are clearly dated today. Do NOT include entries from prior days, even if they are recent.
- Merge any findings into the appropriate topic section (e.g., Claude Code changelog items go into the "Claude Code / Anthropic" section, Copilot items go into "AI Coding IDEs", etc.).
- If a changelog entry duplicates something already found via web search, keep the more detailed version and discard the other.
- If none of the changelogs have entries for today, that is fine — move on.

## Step 2: Compile the Briefing

Format the briefing in TWO tiers:

### Date Attribution Rule

**Every** news item, bullet point, and piece of information MUST include its publication date in parentheses at the end, e.g.:
- "Anthropic released Claude 4.5 Haiku with improved coding benchmarks (Mar 9, 2026)"

If you cannot determine the exact date of a story, note "(date unconfirmed)" and include it only if it is clearly from the past 24 hours based on other signals.

### Tier 1: TL;DR (top of page)
- 10-15 bullet points covering the biggest stories across all topics
- Each bullet: one sentence, include the company/product name and date
- This should be a ~1 minute read

### Tier 2: Full Briefing (below TL;DR)
- 9 sections, one per topic (use ## headings)
- Each section: 3-8 bullet points with details, source attribution, and date
- End with a "Key Takeaways" table summarizing major trends

## Step 3: Write to Notion

**CRITICAL: Never create a duplicate page.** Use the `PAGE_EXISTS` result from Step 0b to decide:

### If PAGE_EXISTS = true (page for today already exists)
Use `mcp__notion__notion-update-page` with the page ID from Step 0b to update the existing page. Replace the content with the new briefing. Update the Topics property if it changed.

### If PAGE_EXISTS = false (no page for today)
Use `mcp__notion__notion-create-pages` to create a new page in the AI Daily Briefing database.

Use these EXACT parameters:
- parent: {"data_source_id": "856794cc-d871-4a95-be2d-2a1600920a19"}
- properties: {"Date": "[TODAY'S DATE] - AI Daily Briefing", "Status": "Complete", "Topics": 9}
- content: The full briefing formatted in Notion-flavored Markdown

**Do NOT re-query Notion here.** Trust Step 0b's result. Re-querying risks false negatives from title format mismatches or API timing, which causes duplicate pages.

### Notion Formatting Rules
- Use ## for section headings
- Use - for bullet points
- Use **bold** for emphasis
- For the Key Takeaways table, use Notion table format:
  <table header-row="true" fit-page-width="true">
    <tr><td>Theme</td><td>Signal</td></tr>
    <tr><td>theme here</td><td>signal here</td></tr>
  </table>
- Use --- for dividers between TL;DR and full briefing
- Use > for notable quotes

## Step 4: Generate Teams Adaptive Card JSON

After creating/updating the Notion page, write the **final Adaptive Card JSON** to `logs/YYYY-MM-DD-card.json`. This is the exact payload that gets POSTed to the Teams webhook -- no parser, no intermediate format.

Use the `Write` tool to save the file. Use the template below, replacing the placeholder values. The notify script (`notify-teams.sh` / `notify-teams.ps1`) will POST this file as-is.

**Do NOT post the card to any webhook yourself. Only write the JSON file. The calling script handles delivery.**

**CRITICAL RULES — the card MUST match the template below exactly:**
- The file must be valid JSON. No trailing commas. No comments.
- Total file size must be under 24KB (Teams limit is 28KB; leave 4KB headroom).
- All text must be ASCII-safe. Use `--` not em dashes. Use straight quotes. No Unicode symbols in bullet text.
- One bullet per story, max ~200 chars each. Two sentences is fine if the story warrants it. Plain text only in bullets.
- Aim for 4-6 bullets per section when there is enough news. Do not pad thin sections — 2-3 bullets is fine if that's all there is.
- Sources are clickable markdown links: `[Title](url)` -- Adaptive Cards support this in TextBlock.
- Keep it professional and scannable. The card should look polished in a Teams channel.

**NON-NEGOTIABLE STRUCTURAL REQUIREMENTS — do NOT invent your own layout:**
- **Header**: MUST be a `Container` with `style: "accent"`, `bleed: true`, containing a `ColumnSet` with title/date on the left and story/topic counts on the right. Do NOT use a plain TextBlock for the header. Do NOT add emoji to the header.
- **Sources**: MUST be a `Container` with `style: "emphasis"` at the bottom of the body, with pipe-separated clickable links in a single TextBlock. Do NOT omit the sources section.
- **Action button**: MUST use `"title": "Open Full Briefing in Notion"` with `"style": "positive"`. Do NOT shorten to "View in Notion" or omit the style.
- **Bullets**: Each bullet MUST be its own separate TextBlock with `"- "` prefix. Do NOT put multiple bullets inside a single TextBlock using `\n\n` or `•` — Teams renders them on one line. One TextBlock per bullet, no exceptions.

**Template** (fill in sections/bullets/sources from the briefing):

```json
{
  "type": "message",
  "attachments": [
    {
      "contentType": "application/vnd.microsoft.card.adaptive",
      "contentUrl": null,
      "content": {
        "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
        "type": "AdaptiveCard",
        "version": "1.4",
        "msteams": { "width": "Full" },
        "body": [
          {
            "type": "Container",
            "style": "emphasis",
            "bleed": true,
            "spacing": "none",
            "items": [
              {
                "type": "ColumnSet",
                "columns": [
                  {
                    "type": "Column",
                    "width": "stretch",
                    "verticalContentAlignment": "center",
                    "items": [
                      { "type": "TextBlock", "text": "AI Daily Briefing", "weight": "bolder", "size": "extraLarge", "color": "accent" },
                      { "type": "TextBlock", "text": "MONTH DAY, YEAR", "size": "medium", "isSubtle": true, "spacing": "none" }
                    ]
                  },
                  {
                    "type": "Column",
                    "width": "auto",
                    "verticalContentAlignment": "center",
                    "items": [
                      { "type": "TextBlock", "text": "N stories", "weight": "bolder", "size": "large", "horizontalAlignment": "right" },
                      { "type": "TextBlock", "text": "M topics", "size": "medium", "isSubtle": true, "spacing": "none", "horizontalAlignment": "right" }
                    ]
                  }
                ]
              }
            ]
          },
          SECTION_BLOCKS_HERE,
          {
            "type": "Container",
            "separator": true,
            "spacing": "large",
            "style": "emphasis",
            "items": [
              { "type": "TextBlock", "text": "**Sources**", "weight": "bolder", "size": "medium", "spacing": "none" },
              { "type": "TextBlock", "text": "[Source Title](https://example.com) | [Source Title](https://example.com) | ...", "wrap": true, "size": "small", "isSubtle": true, "spacing": "small" }
            ]
          }
        ],
        "actions": [
          {
            "type": "Action.OpenUrl",
            "title": "Open Full Briefing in Notion",
            "url": "https://www.notion.so/PAGE_ID",
            "style": "positive"
          }
        ]
      }
    }
  ]
}
```

**Section block pattern** (repeat for each section, replace SECTION_BLOCKS_HERE):

```json
{
  "type": "Container",
  "separator": true,
  "spacing": "medium",
  "items": [
    { "type": "TextBlock", "text": "**SECTION TITLE**", "weight": "bolder", "size": "medium", "wrap": true, "color": "accent" }
  ]
},
{ "type": "TextBlock", "text": "- Bullet text, plain ASCII, max ~200 chars. Two sentences OK.", "wrap": true, "spacing": "small", "size": "small" },
{ "type": "TextBlock", "text": "- Another bullet -- aim for 4-6 per section when news warrants it", "wrap": true, "spacing": "small", "size": "small" }
```

**Sources section rules:**
- Collect the top 5-8 most important source URLs from the web searches used in Step 1.
- Format as pipe-separated clickable links: `[CNBC](url) | [Bloomberg](url) | [TechCrunch](url)`
- Use short display names (publication name only, not full article titles).
- If there are too many sources to fit, prioritize primary/original sources over aggregators.

## Step 5: Update Covered Stories List

After generating the briefing and card, append today's story headlines to `logs/covered-stories.txt`. This file is used for deduplication in future runs.

**Format** — one line per story, date-prefixed:
```
2026-03-09 | Anthropic files dual lawsuits to block Pentagon blacklisting
2026-03-09 | xAI Grok 4.20 Beta Non-Reasoning released with 2M context
```

**Rules:**
- Append to the file (do NOT overwrite existing entries).
- One line per story. Use the short headline, not the full bullet text.
- Prefix each line with the briefing date in `YYYY-MM-DD` format.
- After appending, remove any lines older than 30 days from the file to prevent unbounded growth.

## Important Notes
- Focus on NEWS from the past 24 hours only — not evergreen content, not older stories
- Do NOT repeat stories already in `logs/covered-stories.txt` or in the most recent Notion page (from Step 0)
- If a topic has no significant news today, say "No major updates today" for that section
- Always attribute sources (publication name) and include the publication date
- Every bullet must have a date — no exceptions
- Keep the total briefing concise but comprehensive
- TODAY'S DATE for the title should be in format: "YYYY-MM-DD" (e.g. "2026-03-09")
