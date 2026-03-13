"""Build an Adaptive Card JSON payload from an AI briefing log file.

Usage: python3 build-teams-card.py <log_file>
Writes JSON to stdout (UTF-8).
"""

import json
import re
import sys
from datetime import datetime


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


def get_icon(header):
    for key, icon in ICON_MAP.items():
        if key.lower() in header.lower():
            return icon
    return "\u25AA"


def parse_log(lines):
    """Parse sections, bullets, and sources from the log."""
    sections = []
    sources = []
    current = None

    for line in lines:
        t = line.strip()

        # Skip timestamps, empty lines
        if re.match(r"^\d{4}-\d{2}-\d{2}\s\d{2}:", t):
            continue
        if not t:
            continue
        # Story count metadata
        if re.match(r"^\*\*\d+\s+sections", t):
            continue

        # Source link: - [title](url)
        m = re.match(r"^-\s+\[(.+?)\]\((.+?)\)$", t)
        if m:
            sources.append({"title": m.group(1), "url": m.group(2)})
            continue

        # "Sources:" label
        if t == "Sources:":
            continue

        # Notion creation line
        if "notion.so" in t and "briefing created" in t.lower():
            continue

        # Section header: **1. Something** or **Something**
        m = re.match(r"^\*\*\d*\.?\s*(.+?)\*\*$", t)
        if m:
            current = {"header": m.group(1).strip(". "), "bullets": []}
            sections.append(current)
            continue

        # Bullet point
        m = re.match(r"^-\s+(.+)", t)
        if m and current is not None:
            current["bullets"].append(m.group(1))

    return sections, sources


def build_card(sections, sources):
    """Build the full Adaptive Card payload."""
    now = datetime.now()
    date_display = f"{now.strftime('%B')} {now.day}, {now.year}"

    story_count = sum(len(s["bullets"]) for s in sections)
    section_count = len(sections)

    if not sections:
        sections = [
            {"header": "Status", "bullets": ["Briefing completed successfully."]}
        ]
        story_count = 0
        section_count = 0

    # --- Header banner ---
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
                            "items": [
                                {
                                    "type": "TextBlock",
                                    "text": "\U0001F4F0",
                                    "size": "extraLarge",
                                }
                            ],
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
                                    "text": f"{date_display}  \u00B7  {story_count} stories across {section_count} topics",
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

    # --- Sections with bullets ---
    for section in sections:
        icon = get_icon(section["header"])

        # Section header
        body.append(
            {
                "type": "Container",
                "separator": True,
                "spacing": "large",
                "items": [
                    {
                        "type": "TextBlock",
                        "text": f"{icon}  **{section['header']}**",
                        "weight": "bolder",
                        "size": "large",
                        "wrap": True,
                    }
                ],
            }
        )

        # Bullets
        for bullet in section["bullets"]:
            body.append(
                {
                    "type": "TextBlock",
                    "text": f"\u2022  {bullet}",
                    "wrap": True,
                    "spacing": "small",
                    "size": "medium",
                }
            )

    # --- Sources section ---
    if sources:
        source_lines = "  \n".join(
            f"[{s['title']}]({s['url']})" for s in sources
        )
        body.append(
            {
                "type": "Container",
                "separator": True,
                "spacing": "large",
                "items": [
                    {
                        "type": "TextBlock",
                        "text": "\U0001F517  **Sources**",
                        "weight": "bolder",
                        "size": "medium",
                        "wrap": True,
                        "isSubtle": True,
                    },
                    {
                        "type": "TextBlock",
                        "text": source_lines,
                        "wrap": True,
                        "size": "small",
                        "isSubtle": True,
                        "spacing": "small",
                    },
                ],
            }
        )

    # --- Card envelope ---
    card = {
        "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
        "type": "AdaptiveCard",
        "version": "1.4",
        "msteams": {"width": "Full"},
        "body": body,
    }

    return {
        "type": "message",
        "attachments": [
            {
                "contentType": "application/vnd.microsoft.card.adaptive",
                "contentUrl": None,
                "content": card,
            }
        ],
    }


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 build-teams-card.py <log_file>", file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()

    sections, sources = parse_log(lines)
    payload = build_card(sections, sources)
    sys.stdout.buffer.write(json.dumps(payload, ensure_ascii=False).encode("utf-8"))


if __name__ == "__main__":
    main()
