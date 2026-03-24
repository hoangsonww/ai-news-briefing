#!/usr/bin/env python3
"""Convert a Teams Adaptive Card JSON file to a Slack Block Kit JSON payload.

Reads the Teams card structure (header, sections, bullets, sources, Notion URL)
and produces a Slack-native Block Kit message that looks polished in channels.

Usage:
    python3 teams-to-slack.py <input-card.json> [output-slack.json]

If output file is omitted, writes to stdout.
"""

import json
import re
import sys


def md_links_to_slack(text: str) -> str:
    """Convert [title](url) markdown links to <url|title> Slack mrkdwn."""
    return re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"<\2|\1>", text)


def strip_double_bold(text: str) -> str:
    """Convert **text** to *text* for Slack mrkdwn."""
    return re.sub(r"\*\*([^*]+)\*\*", r"*\1*", text)


def extract_card_data(card_json: dict) -> dict:
    """Extract structured data from a Teams Adaptive Card JSON envelope."""
    content = card_json["attachments"][0]["content"]
    body = content["body"]

    # --- Header (first Container) ---
    header_container = body[0]
    columns = header_container["items"][0]["columns"]
    left = columns[0]["items"]
    right = columns[1]["items"]

    title = left[0]["text"]
    date_text = left[1]["text"]
    story_count = right[0]["text"]
    topic_count = right[1]["text"]

    # --- Sections, bullets, and sources ---
    sections: list[dict] = []
    current_section: dict | None = None
    sources_text: str | None = None

    for element in body[1:]:
        etype = element.get("type")

        if etype == "Container":
            items = element.get("items", [])
            # Sources container: style "emphasis" with 2+ items (label + links)
            if element.get("style") == "emphasis" and len(items) >= 2:
                sources_text = items[1].get("text", "")
                continue
            # Section title container
            if items:
                raw_title = items[0].get("text", "")
                # Strip **bold** wrappers and numbered prefixes like "**1. Title**"
                clean_title = re.sub(r"^\*\*|\*\*$", "", raw_title).strip()
                current_section = {"title": clean_title, "bullets": []}
                sections.append(current_section)

        elif etype == "TextBlock":
            bullet = element.get("text", "")
            if bullet.startswith("- "):
                bullet = bullet[2:]
            # Orphan TextBlocks before first section go into a "Highlights" section
            if current_section is None:
                current_section = {"title": "Highlights", "bullets": []}
                sections.append(current_section)
            current_section["bullets"].append(bullet)

    # --- Notion URL ---
    notion_url = None
    actions = content.get("actions", [])
    if actions:
        notion_url = actions[0].get("url")

    return {
        "title": title,
        "date": date_text,
        "story_count": story_count,
        "topic_count": topic_count,
        "sections": sections,
        "sources_text": sources_text,
        "notion_url": notion_url,
    }


def build_slack_payload(data: dict) -> dict:
    """Build a Slack Block Kit payload from extracted card data."""
    blocks: list[dict] = []

    # Header
    blocks.append({
        "type": "header",
        "text": {"type": "plain_text", "text": data["title"], "emoji": False},
    })

    # Date and counts
    blocks.append({
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": f"*{data['date']}*  |  {data['story_count']}  |  {data['topic_count']}",
        },
    })

    blocks.append({"type": "divider"})

    # Topic sections — each section title + bullets in one mrkdwn block
    for section in data["sections"]:
        cleaned = [strip_double_bold(md_links_to_slack(b)) for b in section["bullets"]]
        bullets = "\n".join(f"\u2022  {b}" for b in cleaned)
        text = f"*{section['title']}*\n{bullets}"
        # Slack section text limit is 3000 chars
        if len(text) > 3000:
            text = text[:2997] + "..."
        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": text},
        })

    blocks.append({"type": "divider"})

    # Sources
    if data["sources_text"]:
        sources_slack = md_links_to_slack(data["sources_text"])
        # Context elements have a 2000 char limit
        if len(sources_slack) > 1990:
            sources_slack = sources_slack[:1987] + "..."
        blocks.append({
            "type": "context",
            "elements": [
                {"type": "mrkdwn", "text": f":newspaper:  *Sources:*  {sources_slack}"},
            ],
        })

    # Notion button
    if data["notion_url"]:
        blocks.append({
            "type": "actions",
            "elements": [
                {
                    "type": "button",
                    "text": {"type": "plain_text", "text": "Open Full Briefing in Notion"},
                    "url": data["notion_url"],
                    "style": "primary",
                },
            ],
        })

    # Fallback text for notifications / non-Block-Kit clients
    fallback = f"{data['title']} -- {data['date']} -- {data['story_count']}, {data['topic_count']}"

    return {"text": fallback, "blocks": blocks}


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: teams-to-slack.py <input-card.json> [output-slack.json]", file=sys.stderr)
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None

    with open(input_path, "r", encoding="utf-8") as f:
        card_json = json.load(f)

    data = extract_card_data(card_json)
    payload = build_slack_payload(data)
    output = json.dumps(payload, indent=2, ensure_ascii=True)

    if output_path:
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(output + "\n")
    else:
        print(output)


if __name__ == "__main__":
    main()
