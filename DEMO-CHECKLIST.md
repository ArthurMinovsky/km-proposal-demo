# Proposal Session Checklist

1. `./scripts/install.sh`
2. Connect the ACP/Agent CLI to `http://localhost:8000/mcp` using `MCP_AUTH_TOKEN` from `.env`.
3. Load `skill/km-management/SKILL.md`.
4. Run `./scripts/ingest.sh demo-imports/project-facts.csv`.
5. Ask the agent: `Search KM for "Retrieval order".`
6. Ask: `Where did that knowledge come from?`
7. Show the preserved source path and SHA-256 in the normalized Markdown frontmatter.
8. Ask one more question from the imported CSV to show immediate retrieval.
9. End with `./scripts/uninstall.sh --restore-all`.
10. Confirm the demo containers are gone and the demo-owned `runtime/vault` is gone.
