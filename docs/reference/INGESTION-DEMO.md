# Ingestion Demo Boundary

This PoC intentionally implements a shorter workflow than the full KM proposal:

`ACP skill -> ingest tool -> normalized Markdown + source metadata + structure index -> Vault Cortex MCP search/read`

The PoC does **not** require review/promotion, embeddings, GraphRAG, or an LLM inside the KM service.

Reference ideas:
- Firecrawl AnyDoc: deterministic local document-to-Markdown conversion.
- PageIndex: preserve structural navigation rather than only arbitrary chunks.
- Revornix: collect/convert/organize pipeline separation.
- AutoFlow: knowledge-base ingestion and agent retrieval.
- Alexandrie: portable durable knowledge organization.

The original file is preserved and generated knowledge keeps its source SHA-256 so the ACP agent can trace retrieved knowledge back to the input.
