#!/usr/bin/env python3
"""Append `_tool` suffix to MCP tool names in the CLAUDE.md block that
upstream `code-review-graph install --platform claude-code` writes.

Upstream docs reference tools like `query_graph`, `detect_changes`, etc.
The actual MCP tool names have a `_tool` suffix (`query_graph_tool`,
`detect_changes_tool`, ...). Calling the documented bare name returns
`Unknown tool: query_graph`. This script fixes the mismatch in the
injected CLAUDE.md block so Claude Code calls real tool names.

Only rewrites inside the upstream-managed block (between the
`<!-- code-review-graph MCP tools -->` marker and the next `<!-- /... -->`
marker or end-of-file). Does not touch the user's own CLAUDE.md content.

Usage: patch-claudemd-tool-names.py <path-to-CLAUDE.md>
Exits 0 on success or if the file/block is absent.
"""
import re
import sys
from pathlib import Path

BARE_NAMES = [
    "query_graph",
    "get_impact_radius",
    "detect_changes",
    "get_review_context",
    "get_affected_flows",
    "semantic_search_nodes",
    "get_architecture_overview",
    "list_communities",
    "build_or_update_graph",
    "get_minimal_context",
    "traverse_graph",
    "get_hub_nodes",
    "get_bridge_nodes",
]

BEGIN = "<!-- code-review-graph MCP tools -->"


def patch(text: str) -> str:
    start = text.find(BEGIN)
    if start < 0:
        return text
    # Block runs to EOF or next HTML comment that isn't the opener.
    remainder = text[start:]

    def replace_in_block(block: str) -> str:
        for name in BARE_NAMES:
            pattern = rf"`{name}(?!_tool)`"
            block = re.sub(pattern, f"`{name}_tool`", block)
        return block

    return text[:start] + replace_in_block(remainder)


def main() -> int:
    if len(sys.argv) < 2:
        return 0
    path = Path(sys.argv[1])
    if not path.exists():
        return 0
    original = path.read_text()
    patched = patch(original)
    if patched != original:
        path.write_text(patched)
    return 0


if __name__ == "__main__":
    sys.exit(main())
