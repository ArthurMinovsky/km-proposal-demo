# KM Proposal Demo — ACP + MCP + Obsidian + File Ingestion

Disposable proof-of-concept for the KM proposal.

The demo has two persistent Docker services and one disposable tool container:

- **`mcp`** — Vault Cortex, exposing the Markdown vault through MCP.
- **`obsidian-server`** — optional headless Obsidian Sync transport.
- **`ingest`** — one-shot AnyDoc-based file converter. It runs only when `./scripts/ingest.sh` is called.

The **ACP / Agent CLI is the reasoning layer**. The KM Docker stack does not need an LLM provider, model API key, embedding API, or GraphRAG service.

## Demo flow

```text
file
  ↓
./scripts/ingest.sh
  ↓
preserve original + SHA-256
  ↓
AnyDoc → normalized Markdown
  ↓
lightweight heading-tree INDEX.md
  ↓
Vault Cortex indexes Markdown
  ↓
ACP Agent CLI + KM skill → MCP search/read
```

There is **no review or approval gate in this PoC**. Imported knowledge becomes searchable immediately.

## Why these references

The implementation deliberately borrows only the smallest useful ideas:

- **Vault Cortex** — Markdown vault + MCP + rebuildable search index.
- **Firecrawl AnyDoc** — local Office/PDF/CSV/etc. → GitHub-Flavored Markdown conversion.
- **PageIndex** — inspiration for retaining document structure/tree rather than treating a document as an opaque blob. This demo generates a simple deterministic heading tree; it does not run PageIndex or require an LLM.
- **Revornix** — reference for a pluggable collect → convert → organize ingestion pipeline.
- **AutoFlow** — reference for knowledge-base ingestion and agent retrieval patterns.
- **Alexandrie** — reference for durable, portable Markdown-oriented knowledge organization.

## Layout

```text
km-proposal-demo/
├── docker-compose.yml
├── Dockerfile.ingest
├── .env.example
├── demo-imports/
│   └── project-facts.csv
├── demo-vault/
│   ├── PROJECT.md
│   ├── REQUIREMENTS.md
│   ├── CONTEXT.md
│   ├── PROGRESS.md
│   ├── source/imported/
│   ├── knowledge/imported/
│   └── .km/ingest/
├── tools/
│   └── ingest.mjs
├── scripts/
│   ├── install.sh
│   ├── ingest.sh
│   ├── status.sh
│   ├── uninstall.sh
│   └── verify.sh
├── skill/km-management/SKILL.md
└── docs/reference/KM-management.md
```

# Installation

## Prerequisites

- Docker with Docker Compose v2.
- An ACP/Agent CLI capable of using an MCP server and a local skill.
- For the optional `obsidian-server`: an active Obsidian Sync subscription and a disposable/demo remote vault.

## 1. Install the local demo

```bash
./scripts/install.sh
```

The installer:

1. creates `.env` from `.env.example` if needed;
2. generates a random MCP bearer token;
3. seeds a project-local demo vault at `runtime/vault`;
4. builds the one-shot ingestion image with Firecrawl AnyDoc;
5. starts Vault Cortex MCP.

MCP endpoint:

```text
http://localhost:9705/mcp
```

Use `MCP_AUTH_TOKEN` from `.env`.

## 2. Configure MCP in your Agent CLI

Add the `km-vault` MCP server to your agent CLI configuration:

### OpenCode (`~/.config/opencode/opencode.json`)
```json
{
  "mcp": {
    "km-vault": {
      "type": "remote",
      "url": "http://localhost:9705/mcp",
      "headers": {
        "Authorization": "Bearer <YOUR_MCP_AUTH_TOKEN>"
      },
      "enabled": true
    }
  }
}
```

### Claude Desktop / Claude Code (`claude_desktop_config.json` / `mcp.json`)
```json
{
  "mcpServers": {
    "km-vault": {
      "url": "http://localhost:9705/mcp",
      "headers": {
        "Authorization": "Bearer <YOUR_MCP_AUTH_TOKEN>"
      }
    }
  }
}
```

### Codex (`~/.codex/config.toml`)
```toml
[mcp_servers.km_vault]
url = "http://localhost:9705/mcp"
headers = { "Authorization" = "Bearer <YOUR_MCP_AUTH_TOKEN>" }
```

## 3. Load the KM skill into the ACP agent

Copy:

```text
skill/km-management/
```

into the skill location used by your ACP/Agent CLI (e.g. `~/.claude/skills/`, `~/.codex/skills/`, `~/.config/opencode/skills/`, or `~/.gemini/config/skills/`).

The skill contains workflow instructions only. It installs no daemon and calls no model provider.

## 4. Ingest a file or directory

Included demo:

```bash
./scripts/ingest.sh demo-imports/project-facts.csv
```

Or use your own file or repository directory:

```bash
./scripts/ingest.sh /path/to/report.docx
./scripts/ingest.sh /path/to/slides.pptx
./scripts/ingest.sh /path/to/paper.pdf
./scripts/ingest.sh /path/to/notebook.ipynb
./scripts/ingest.sh /path/to/source_code_or_repo_dir/
```

For each successful import the tool creates:

```text
runtime/vault/
├── source/imported/DOC-.../<original file>
├── knowledge/imported/DOC-...-<name>.md
├── knowledge/imported/DOC-...-<name>.index.md
└── .km/ingest/DOC-....json
```

The document ID is derived from the source SHA-256. Re-ingesting identical bytes produces the same ID.

The normalized Markdown frontmatter records:

- document ID;
- preserved source path;
- source SHA-256 revision;
- original filename;
- import time;
- generator.

Vault Cortex then sees the new Markdown and makes it available to MCP search.

## Supported file conversion

The ingestion container handles:

- **Office & Documents** (via Firecrawl AnyDoc): Word, PowerPoint, Excel, OpenDocument, RTF, EPUB, CSV, text-based PDF.
- **Jupyter Notebooks** (`.ipynb`): Markdown cells and Python code cells rendered cleanly with heading indices.
- **Source Code & Data** (`.py`, `.js`, `.ts`, `.html`, `.css`, `.json`, `.yaml`, `.sh`): Syntax-highlighted Markdown with AST/symbol heading extraction.
- **Directories**: Recursive directory traversal and batch conversion.
- **Markdown & Plain text**: Local passthrough.

**Demo limitation:** scanned/image-only PDFs require OCR and are not handled by local AnyDoc.

# Proposal-session demo

A short demo is enough:

```bash
./scripts/install.sh
./scripts/ingest.sh demo-imports/project-facts.csv
```

Then in the ACP agent:

1. load the KM skill;
2. ask: `Search KM for "Retrieval order".`
3. ask: `Where did that knowledge come from?`
4. ask: `What is the agent interface in the imported document?`

The agent should use MCP search/read and be able to show that the normalized note links back to the preserved CSV plus its SHA-256 revision.

That demonstrates:

```text
unstructured/office file
→ normalized durable knowledge
→ source traceability
→ immediate agent retrieval
```

# Optional Obsidian server

`obsidian-server` is behind the `obsidian-sync` Compose profile.

Get a token using the upstream image helper, configure `.env`, then run:

```bash
./scripts/install.sh --with-obsidian-sync
```

Set at least:

```dotenv
OBSIDIAN_AUTH_TOKEN=...
VAULT_NAME=Exact Demo Remote Vault Name
```

Use a **disposable remote vault for the demo**. Obsidian Sync is external state: deleting local Docker containers cannot automatically erase copies already synchronized to an Obsidian remote vault.

# Status

```bash
./scripts/status.sh
```

This shows container state, MCP health, local runtime sizes, and imported-document count.

# Uninstall / Restore to Normal

Uninstall is intentionally a first-class part of this PoC.

## Safe stop — keep demo data

```bash
./scripts/uninstall.sh
```

Removes the demo containers/network but retains the project-local vault and index data so the demo can restart.

## Remove demo-owned runtime data

```bash
./scripts/uninstall.sh --purge-demo-data
```

The local vault is deleted **only if**:

```text
runtime/vault/.km-demo-owned
```

exists. The installer creates that sentinel only for the disposable vault it owns.

This removes:

- imported originals created inside the demo vault;
- generated normalized Markdown;
- generated structure indexes/manifests;
- MCP local index/log data;
- local Obsidian headless configuration.

## Full local restore

```bash
./scripts/uninstall.sh --restore-all
```

This additionally:

- removes generated `.env`;
- removes install state;
- attempts to remove the local ingest image;
- attempts to remove the two upstream demo images.

Docker may keep an image if another container still uses it.

Then delete the extracted source folder if desired:

```bash
cd ..
rm -rf km-proposal-demo
```

## What this demo never installs on the host

It does not install or alter:

- Docker itself;
- Obsidian desktop;
- Node/npm globally on the host;
- AnyDoc globally on the host;
- shell startup files;
- launch agents/systemd services;
- cron jobs/login items;
- Docker daemon settings.

AnyDoc exists only inside the disposable `ingest` image.

## Important external-vault warning

The default `VAULT_HOST_PATH=./runtime/vault` is fully disposable.

If you manually change `VAULT_HOST_PATH` to an existing vault, imported files become real user data in that vault and the uninstall script intentionally does **not** delete the external vault.

For a proposal demo, keep the default local vault.

If you enable Obsidian Sync, use a disposable remote demo vault. Local uninstall cannot reverse remote sync history.

# Verification

Before the session:

```bash
./scripts/verify.sh
```

After install:

```bash
./scripts/status.sh
```

After the session:

```bash
./scripts/uninstall.sh --restore-all
```

# Reference repositories

- https://github.com/aliasunder/vault-cortex
- https://github.com/firecrawl/anydoc
- https://github.com/VectifyAI/PageIndex
- https://github.com/Qingyon-AI/Revornix
- https://github.com/pingcap/autoflow
- https://github.com/Smaug6739/Alexandrie
