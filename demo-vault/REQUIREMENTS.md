---
title: KM Requirements
type: requirements
authority: authoritative
tags: [km, requirements, demo]
---
# KM Requirements

- KM-FR-001: Markdown files are the durable source of truth.
- KM-FR-002: Derived indexes accelerate retrieval but never override authoritative Markdown.
- KM-FR-003: Retrieve the smallest sufficient authoritative context first.
- KM-FR-004: Agent-authored changes are proposed and reviewed before authority promotion.
- KM-FR-005: Decisions, progress, and evidence remain traceable across sessions.

## Controlled write rule
New agent-authored knowledge goes to `proposals/` unless the user explicitly authorizes promotion into an authoritative source.
