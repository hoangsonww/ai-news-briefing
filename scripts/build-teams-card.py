"""Build an Adaptive Card JSON payload from an AI briefing log file.

Usage: python3 build-teams-card.py <log_file>
Writes JSON to stdout (UTF-8).
"""

import json
import re
import sys
from datetime import datetime

MAX_CARD_BYTES = 26_000  # Teams limit is 28KB; leave headroom

ICON_MAP = {
    "Claude": "\U0001F916",
    "Anthropic": "\U0001F916",
    "NVIDIA": "\U0001F4BB",
    "GTC": "\U0001F4BB",
    "Policy": "\u2696\uFE0F",
    "Regulation": "\u2696\uFE0F",
    "Industry": "\U0001F3ED",
    "Open Source": "\U0001F513",
    "Coding": "\U0001F4DD",
    "IDE": "\U0001F4DD",
    "Agentic": "\U0001F517",
    "Startup": "\U0001F680",
    "Funding": "\U0001F680",
    "Dev Tool": "\U0001F527",
    "Framework": "\U0001F527",
    "OpenAI": "\u2728",
    "ChatGPT": "\u2728",
}

# Common encoding artifacts from Windows cp1252 / Notion fetch
ENCODING_FIXES = {
    "\u0393\u00C7\u00F6": "\u2014",  # em dash
    "\u0393\u00C7\u00F4": "\u2013",  # en dash
    "\u0393\u00C7\u00D6": "\u2018",  # left single quote
    "\u0393\u00C7\u00D8": "\u2019",  # right single quote
    "\u0393\u00C7\u00EC": "\u201C",  # left double quote
    "\u0393\u00C7\u00EE": "\u201D",  # right double quote
    "\u251C\u00F9": "\u00D7",        # multiplication sign
}


def fix_encoding(text):
    """Replace common encoding artifacts with correct Unicode characters."""
    for bad, good in ENCODING_FIXES.items():
        text = text.replace(bad, good)
    return text


def get_icon(header):
    for key, icon in ICON_MAP.items():
        if key.lower() in header.lower():
            return icon
    return "\u25AA"


def parse_log(lines):
    """Parse sections, bullets, and sources from the log.

    Handles two content formats:
    - Short stdout summary: **bold headers** + short bullets (old format)
    - Full briefing output: ## headings + rich bullets with bold headlines (new format)
    """
    sections = []
    sources = []
    tldr_bullets = []
    current = None
    in_sources = False
    in_tldr = False
    in_key_takeaways = False
    notion_url = None

    for line in lines:
        t = fix_encoding(line.strip())

        # Skip timestamps and empty lines
        if re.match(r"^\d{4}-\d{2}-\d{2}\s\d{2}:", t):
            continue
        if not t:
            continue

        # Extract Notion URL (Step 4 format: "Notion: <url>" or legacy)
        m = re.search(r"https://www\.notion\.so/\S+", t)
        if m and notion_url is None:
            notion_url = m.group(0)

        # Skip metadata / dividers
        if re.match(r"^\*\*\d+\s+sections", t):
            continue
        if t == "---":
            in_tldr = False
            continue

        # Sources section toggle
        if re.match(r"^#+\s*Sources?$", t, re.IGNORECASE) or t == "Sources:":
            in_sources = True
            in_tldr = False
            in_key_takeaways = False
            continue

        # Key Takeaways — skip the table, it doesn't render in Adaptive Cards
        if re.match(r"^#+\s*Key Takeaways", t, re.IGNORECASE):
            in_key_takeaways = True
            in_sources = False
            in_tldr = False
            continue
        if in_key_takeaways:
            continue

        # Source link: - [title](url)
        if in_sources:
            m = re.match(r"^-\s+\[(.+?)\]\((.+?)\)", t)
            if m:
                sources.append({"title": m.group(1), "url": m.group(2)})
            continue

        # ## TL;DR section header
        if re.match(r"^#+\s*TL;DR", t, re.IGNORECASE):
            in_tldr = True
            in_sources = False
            continue

        # TL;DR bullets — collect separately, will become first section
        if in_tldr:
            m = re.match(r"^-\s+(.+)", t)
            if m:
                bullet = re.sub(r"\*\*(.+?)\*\*", r"\1", m.group(1))
                tldr_bullets.append(bullet)
            continue

        # ## N. Section heading (full briefing format)
        m = re.match(r"^#+\s+\d+\.\s+(.+)", t)
        if m:
            current = {"header": m.group(1).strip(), "bullets": []}
            sections.append(current)
            in_sources = False
            in_tldr = False
            continue

        # ## Section heading without number
        m = re.match(r"^#+\s+(.+)", t)
        if m:
            header = m.group(1).strip()
            if re.search(r"sources?|key takeaways", header, re.IGNORECASE):
                continue
            current = {"header": header, "bullets": []}
            sections.append(current)
            in_sources = False
            in_tldr = False
            continue

        # **Bold section header** (short stdout format)
        m = re.match(r"^\*\*\d*\.?\s*(.+?)\*\*$", t)
        if m:
            header = m.group(1).strip(". ")
            if not re.search(r"sections?|stories", header, re.IGNORECASE):
                current = {"header": header, "bullets": []}
                sections.append(current)
            continue

        # Table row: | Section | Key Stories |
        m = re.match(r"^\|\s*(.+?)\s*\|\s*(.+?)\s*\|$", t)
        if m:
            col1 = m.group(1).strip()
            col2 = m.group(2).strip()
            # Skip header/separator rows
            if col1.startswith("---") or col1.lower() == "section":
                continue
            # Each row becomes a section with stories split on ; or ,
            stories = re.split(r"\s*[;]\s*", col2)
            section = {"header": col1, "bullets": [s.strip() for s in stories if s.strip()]}
            sections.append(section)
            continue

        # Bullet point
        m = re.match(r"^-\s+(.+)", t)
        if m and current is not None:
            bullet = m.group(1)
            bullet = re.sub(r"\*\*(.+?)\*\*\s*[—–-]\s*", r"\1 — ", bullet)
            bullet = re.sub(r"\*\*(.+?)\*\*", r"\1", bullet)
            current["bullets"].append(bullet)

    if tldr_bullets:
        sections.insert(0, {"header": "TL;DR", "bullets": tldr_bullets})

    return sections, sources, notion_url


def build_card(sections, sources, notion_url=None):
    """Build the full Adaptive Card payload."""
    now = datetime.now()
    date_display = f"{now.strftime('%B')} {now.day}, {now.year}"

    topic_sections = [s for s in sections if s["header"].upper() != "TL;DR"]
    story_count = sum(len(s["bullets"]) for s in topic_sections)
    section_count = len(topic_sections)

    if not sections:
        sections = [{"header": "Status", "bullets": ["Briefing completed successfully."]}]
        story_count = 0
        section_count = 0

    # ── Header ─────────────────────────────────────────────────────────────────
    body = [
        {
            "type": "Container",
            "style": "accent",
            "bleed": True,
            "spacing": "none",
            "items": [
                {
                    "type": "ColumnSet",
                    "columns": [
                        {
                            "type": "Column",
                            "width": "auto",
                            "verticalContentAlignment": "center",
                            "items": [{"type": "TextBlock", "text": "\U0001F4F0", "size": "extraLarge"}],
                        },
                        {
                            "type": "Column",
                            "width": "stretch",
                            "verticalContentAlignment": "center",
                            "items": [
                                {
                                    "type": "TextBlock",
                                    "text": "AI Daily Briefing",
                                    "weight": "bolder",
                                    "size": "extraLarge",
                                    "color": "light",
                                },
                                {
                                    "type": "TextBlock",
                                    "text": f"{date_display}  \u00B7  {story_count} stories  \u00B7  {section_count} topics",
                                    "size": "medium",
                                    "color": "light",
                                    "isSubtle": True,
                                    "spacing": "none",
                                },
                            ],
                        },
                    ],
                }
            ],
        }
    ]

    # ── Sections ───────────────────────────────────────────────────────────────
    for section in sections:
        is_tldr = section["header"].upper() == "TL;DR"
        icon = "\U0001F4CB" if is_tldr else get_icon(section["header"])
        count = len(section["bullets"])

        # Section header with inline story count
        header_text = f"{icon}  **{section['header']}**"
        if not is_tldr and count > 0:
            header_text += f"  \u00B7  {count} {'story' if count == 1 else 'stories'}"

        body.append(
            {
                "type": "Container",
                "separator": True,
                "spacing": "large",
                "style": "emphasis" if is_tldr else "default",
                "items": [
                    {
                        "type": "TextBlock",
                        "text": header_text,
                        "weight": "bolder",
                        "size": "large",
                        "wrap": True,
                    }
                ],
            }
        )

        for bullet in section["bullets"]:
            body.append({
                "type": "TextBlock",
                "text": f"\u2022  {bullet}",
                "wrap": True,
                "spacing": "small",
                "size": "medium",
            })

    # ── Sources ────────────────────────────────────────────────────────────────
    if sources:
        source_items = [
            {
                "type": "TextBlock",
                "text": "\U0001F4DA  **Sources**",
                "weight": "bolder",
                "size": "medium",
                "spacing": "none",
            }
        ]
        for s in sources:
            source_items.append({
                "type": "TextBlock",
                "text": f"\u2022  [{s['title']}]({s['url']})",
                "wrap": True,
                "size": "small",
                "spacing": "small",
            })

        body.append(
            {
                "type": "Container",
                "separator": True,
                "spacing": "large",
                "style": "emphasis",
                "items": source_items,
            }
        )

    # ── Card ───────────────────────────────────────────────────────────────────
    card = {
        "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
        "type": "AdaptiveCard",
        "version": "1.4",
        "msteams": {"width": "Full"},
        "body": body,
    }

    if notion_url:
        card["actions"] = [
            {
                "type": "Action.OpenUrl",
                "title": "\U0001F4D3  Open Full Briefing in Notion",
                "url": notion_url,
            }
        ]

    payload = {
        "type": "message",
        "attachments": [
            {
                "contentType": "application/vnd.microsoft.card.adaptive",
                "contentUrl": None,
                "content": card,
            }
        ],
    }

    # ── Size enforcement ───────────────────────────────────────────────────────
    encoded = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    if len(encoded) > MAX_CARD_BYTES:
        # Trim bullet text progressively
        for item in body:
            if item.get("type") == "TextBlock" and item["text"].startswith("\u2022"):
                t = item["text"]
                if len(t) > 150:
                    item["text"] = t[:147] + "..."
        encoded = json.dumps(payload, ensure_ascii=False).encode("utf-8")

    # Last resort: drop sources
    if len(encoded) > MAX_CARD_BYTES and body:
        last = body[-1]
        if last.get("type") == "Container" and any(
            "\U0001F517" in i.get("text", "") for i in last.get("items", [])
        ):
            body.pop()

    return payload


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 build-teams-card.py <log_file>", file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()

    sections, sources, notion_url = parse_log(lines)
    payload = build_card(sections, sources, notion_url)
    sys.stdout.buffer.write(json.dumps(payload, ensure_ascii=False).encode("utf-8"))


if __name__ == "__main__":
    main()
