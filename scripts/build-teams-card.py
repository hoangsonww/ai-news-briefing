"""Build an Adaptive Card JSON payload from an AI briefing log file.

Usage: python3 build-teams-card.py <log_file>
Writes JSON to stdout (UTF-8).

Note: Not used actively anymore, since we now delegate card building to the AI, but still useful for debugging and as a reference implementation for the expected card structure.
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
    "Google": "\U0001F50D",
    "Gemini": "\U0001F50D",
}

# Common encoding artifacts from Windows cp1252 / Notion fetch
ENCODING_FIXES = {
    "\u0393\u00C7\u00F6": "\u2014",  # em dash —
    "\u0393\u00C7\u00F4": "\u2013",  # en dash –
    "\u0393\u00C7\u00D6": "\u2018",  # left single quote '
    "\u0393\u00C7\u00D8": "\u2019",  # right single quote '
    "\u0393\u00C7\u00EC": "\u201C",  # left double quote "
    "\u0393\u00C7\u00EE": "\u201D",  # right double quote "
    "\u251C\u00F9": "\u00D7",        # multiplication sign ×
    "\u0393\u00E5\u00C6": "\u2192",  # right arrow →
    "\u252C\u2556": "\u00B7",        # middle dot ·
    "\u252C\u00BA": "\u00A7",        # section sign §
}

# Phrases that indicate metadata/status lines — never section content.
_METADATA_PHRASES = [
    "posted to notion",
    "briefing published",
    "briefing updated",
    "briefing created",
    "briefing complete",
    "is live in notion",
    "created in notion",
    "updated in notion",
    "sections covering",
    "items added across",
    "insertions across",
    "what's new",
    "what's covered",
    "what was found",
    "topics covered",
    "topics updated",
    "skipped from search",
    "deduplication:",
    "excluded to avoid",
    "already had comprehensive",
    "topics count unchanged",
    "biggest story of the day",
    "also added to the tl;dr",
    "tl;dr was also updated",
    "tl;dr section was also updated",
    "were also added to the tl;dr",
    "view the full briefing",
    "view the page",
    "check notion for",
    "sending teams notification",
    "teams notification sent",
    "log missing full content",
    "full content fetched",
    "previous state:",
    "open in notion",
    "open full briefing",
]

_METADATA_PATTERNS = [
    r"^Done\.\s",
    r"^Page:\s",
    r"^\*\*Page:\*\*",
    r"^\[View page\]",
    r"^\*{0,2}\d+\s+sections?,?\s+\d+\s+stories?",
    r"^\*{0,2}\d+\s+new items?\s+added",
    r"^\*{0,2}\d+\s+topics?\s+covered",
    r"^March\s+\d+\s+briefing\s+(created|updated)",
    r"^The\s+(existing|March)\s+",
    r"^All\s+\d+\s+items?\s+(were\s+)?also",
    r"^Briefing created",
    r"^Topics\s+updated:",
]


def fix_encoding(text):
    """Replace common encoding artifacts with correct Unicode characters."""
    for bad, good in ENCODING_FIXES.items():
        text = text.replace(bad, good)
    return text


def _is_metadata(text):
    """Return True for status/meta lines that should never become sections."""
    lc = text.lower()
    if any(phrase in lc for phrase in _METADATA_PHRASES):
        return True
    return any(re.match(p, text, re.IGNORECASE) for p in _METADATA_PATTERNS)


def _clean_header(text):
    """Normalize a section header: strip prefixes, numbering, bold markers."""
    text = re.sub(r"\*+", "", text)  # strip all markdown emphasis (* and **)
    text = re.sub(r"^Added to\s+", "", text, flags=re.IGNORECASE)
    # "Section 1 (" or "Section 1 —" or "Section 1:"
    text = re.sub(r"^Section\s+\d+\s*[\(\u2014\u2013\-:]\s*", "", text)
    # Leading number/symbol: "1. ", "§1 ", "┬º1 ", "#1 "
    text = re.sub(r"^[\u00A7\u252C\u00BA#]*\d+\.?\s*", "", text)
    # Annotations: "(3 new)", "(new)", "(4 new regulatory actions)", "(2 updates)"
    text = re.sub(
        r"\s*\(\d*\s*(?:new|update[sd]?|added)[^)]*\)", "", text, flags=re.IGNORECASE
    )
    text = text.rstrip("):. ")
    return text.strip()


def _clean_bullet(text):
    """Normalize bullet text: strip bold, clean headline separators."""
    text = re.sub(r"\*\*(.+?)\*\*\s*[—–:\-]\s*", r"\1 — ", text)
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text)
    return text.strip()


def get_icon(header):
    for key, icon in ICON_MAP.items():
        if key.lower() in header.lower():
            return icon
    return "\u25AA"


def parse_log(lines):
    """Parse sections, bullets, and sources from the briefing log.

    Handles all known output formats:
    - Numbered bold:   1. **Header** — description
    - Bold numbered:   **1. Header**
    - Bold plain:      **Header** or **Header:**
    - Section ref:     **Section N (Header):** or **Section N — Header:**
    - Added-to:        **Added to Section N (Header):**
    - Table rows:      | Header | story1; story2 |
    - Markdown h2:     ## N. Header
    - Bold annotated:  **Header (N new):**
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

        # ── Phase 0: skip non-content ──────────────────────────────────────
        if re.match(r"^\d{4}-\d{2}-\d{2}\s\d{2}:", t):
            continue
        if not t:
            continue

        # Extract Notion URL from any format (always keep latest)
        url_m = re.search(r"https://www\.notion\.so/[A-Za-z0-9_-]+", t)
        if url_m:
            notion_url = url_m.group(0)

        # Skip metadata / status lines
        if _is_metadata(t):
            continue
        if t == "---":
            in_tldr = False
            continue

        # ── Phase 1: special sections ──────────────────────────────────────

        # Sources header (## Sources, Sources:, **Sources**)
        if re.match(r"^(#{1,3}\s*)?\*{0,2}Sources?:?\*{0,2}$", t, re.IGNORECASE):
            in_sources = True
            in_tldr = False
            in_key_takeaways = False
            continue

        # Key Takeaways — skip entirely (tables don't render in Cards)
        if re.match(r"^(#{1,3}\s*)?\*{0,2}Key Takeaways", t, re.IGNORECASE):
            in_key_takeaways = True
            in_sources = False
            in_tldr = False
            continue
        if in_key_takeaways:
            # Exit on any line that looks like a new section header
            if re.match(r"^(#{2,}\s|\*\*|\d+\.\s+\*\*|\|)", t):
                in_key_takeaways = False
                # fall through to section matching
            else:
                continue

        # Source links
        if in_sources:
            m = re.match(r"^-\s+\[(.+?)\]\((.+?)\)", t)
            if m:
                sources.append({"title": m.group(1), "url": m.group(2)})
                continue
            # Non-link line: exit sources mode, fall through
            in_sources = False

        # TL;DR header (## TL;DR, **TL;DR**, **TL;DR** — ..., **Added to TL;DR:**)
        if re.match(r"^(#{1,3}\s*)?\*{0,2}(Added to\s+)?TL;DR", t, re.IGNORECASE):
            in_tldr = True
            in_sources = False
            continue

        if in_tldr:
            m = re.match(r"^-\s+(.+)", t)
            if m:
                tldr_bullets.append(_clean_bullet(m.group(1)))
                continue
            # Non-bullet line: exit TL;DR, fall through to section matching
            in_tldr = False

        # ── Phase 2: section headers (most specific → least specific) ──────

        # 2a. Markdown heading with number: ## 1. Header
        m = re.match(r"^#{2,}\s+\d+\.\s+(.+)", t)
        if m:
            header = _clean_header(m.group(1))
            if header:
                current = {"header": header, "bullets": []}
                sections.append(current)
            in_sources = False
            in_tldr = False
            continue

        # 2b. Markdown heading without number: ## Header
        m = re.match(r"^#{2,}\s+(.+)", t)
        if m:
            raw = m.group(1).strip()
            if not re.match(r"(sources?|key takeaways)$", raw, re.IGNORECASE):
                header = _clean_header(raw)
                if header:
                    current = {"header": header, "bullets": []}
                    sections.append(current)
                    in_sources = False
                    in_tldr = False
            continue

        # 2c. Numbered bold with description: 1. **Header** — description
        m = re.match(r"^\d+\.\s+\*\*(.+?)\*\*\s*[—–:\-]\s*(.+)", t)
        if m:
            header = _clean_header(m.group(1))
            desc = _clean_bullet(m.group(2))
            current = {"header": header, "bullets": [desc] if desc else []}
            sections.append(current)
            continue

        # 2d. Numbered bold without description: 1. **Header**
        m = re.match(r"^\d+\.\s+\*\*(.+?)\*\*\s*$", t)
        if m:
            header = _clean_header(m.group(1))
            if header:
                current = {"header": header, "bullets": []}
                sections.append(current)
            continue

        # 2e. Bold "Section N" reference with separator:
        #     **Section 1 (Header):**  /  **Section 1 — Header:**
        #     **Added to Section 1 (Header):**
        m = re.match(
            r"^\*\*(?:Added to\s+)?Section\s+\d+\s*"
            r"[\(\u2014\u2013\-:]\s*(.+?)[\):]?\*\*:?\s*$",
            t,
        )
        if m:
            header = _clean_header(m.group(1))
            if header:
                current = {"header": header, "bullets": []}
                sections.append(current)
            continue

        # 2f. Bold numbered header: **1. Header** or **N Header**
        m = re.match(r"^\*\*\d+\.?\s+(.+?)\*\*:?\s*$", t)
        if m:
            header = _clean_header(m.group(1))
            if header:
                current = {"header": header, "bullets": []}
                sections.append(current)
            continue

        # 2g. Bold standalone header: **Header** or **Header:**
        #     (catch-all for any remaining bold headers)
        m = re.match(r"^\*\*(.+?)\*\*:?\s*$", t)
        if m:
            header = _clean_header(m.group(1))
            if header:
                current = {"header": header, "bullets": []}
                sections.append(current)
            continue

        # 2h. Table row: | Section | Key Stories |
        m = re.match(r"^\|\s*(.+?)\s*\|\s*(.+?)\s*\|$", t)
        if m:
            col1 = m.group(1).strip()
            col2 = m.group(2).strip()
            # Skip header/separator rows
            if col1.startswith("---") or col1.lower() in (
                "section",
                "topic",
                "category",
            ):
                continue
            header = _clean_header(col1)
            if not header:
                continue
            # Split stories on ; · ┬╖ or similar separators
            stories = re.split(r"\s*[;\u00B7\u252C\u2556]\s*", col2)
            stories = [_clean_bullet(s) for s in stories if s.strip()]
            section = {"header": header, "bullets": stories}
            sections.append(section)
            current = section
            continue

        # ── Phase 3: bullets ───────────────────────────────────────────────
        m = re.match(r"^-\s+(.+)", t)
        if m and current is not None:
            current["bullets"].append(_clean_bullet(m.group(1)))

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
            "\U0001F4DA" in i.get("text", "") for i in last.get("items", [])
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
