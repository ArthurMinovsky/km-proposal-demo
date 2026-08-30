#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

const vault = process.env.VAULT_PATH || path.resolve(process.cwd(), "runtime/vault");
const args = process.argv.slice(2);

if (!args.length || args.includes("-h") || args.includes("--help")) {
  console.log(`Usage: node tools/search.mjs <query> [options]
Options:
  --id <doc-id>       Search by exact or prefix Document ID (e.g. DOC-C53E)
  --json              Output raw JSON results
  --limit <n>         Max results to return (default: 10)
  --vault <path>      Override vault path (default: ${vault})
`);
  process.exit(0);
}

let query = "";
let searchId = "";
let asJson = false;
let limit = 10;
let customVault = vault;

for (let i = 0; i < args.length; i++) {
  if (args[i] === "--json") {
    asJson = true;
  } else if (args[i] === "--limit" && args[i + 1]) {
    limit = parseInt(args[++i], 10) || 10;
  } else if (args[i] === "--id" && args[i + 1]) {
    searchId = args[++i].trim();
  } else if (args[i] === "--vault" && args[i + 1]) {
    customVault = path.resolve(args[++i]);
  } else if (!args[i].startsWith("--") && !query) {
    query = args[i];
  }
}

if (!fs.existsSync(customVault)) {
  console.error(`Vault directory not found: ${customVault}`);
  process.exit(1);
}

function walkMarkdownFiles(dir) {
  const results = [];
  if (!fs.existsSync(dir)) return results;
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name.startsWith(".")) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...walkMarkdownFiles(full));
    } else if (entry.isFile() && entry.name.endsWith(".md")) {
      results.push(full);
    }
  }
  return results;
}

const metaDir = path.join(customVault, ".km", "ingest");
const manifests = new Map();
if (fs.existsSync(metaDir)) {
  const metaFiles = fs.readdirSync(metaDir).filter(f => f.endsWith(".json"));
  for (const mf of metaFiles) {
    try {
      const data = JSON.parse(fs.readFileSync(path.join(metaDir, mf), "utf8"));
      manifests.set(data.id, data);
    } catch {}
  }
}

const mdFiles = walkMarkdownFiles(customVault);
const results = [];

for (const file of mdFiles) {
  const content = fs.readFileSync(file, "utf8");
  const relPath = path.relative(customVault, file);
  
  // Extract frontmatter
  let docId = "";
  let sourcePath = "";
  let sourceRevision = "";
  let originalFilename = "";
  
  const fmM = /^---\r?\n([\s\S]*?)\r?\n---/.exec(content);
  if (fmM) {
    const fm = fmM[1];
    const idM = /^id:\s*([^\r\n]+)/m.exec(fm);
    if (idM) docId = idM[1].trim().replace(/^["']|["']$/g, "");
    const srcM = /^source:\s*([^\r\n]+)/m.exec(fm);
    if (srcM) sourcePath = srcM[1].trim().replace(/^["']|["']$/g, "");
    const revM = /^source_revision:\s*([^\r\n]+)/m.exec(fm);
    if (revM) sourceRevision = revM[1].trim().replace(/^["']|["']$/g, "");
    const origM = /^original_filename:\s*([^\r\n]+)/m.exec(fm);
    if (origM) originalFilename = origM[1].trim().replace(/^["']|["']$/g, "");
  }

  const manifest = manifests.get(docId) || {};
  if (!originalFilename && manifest.original_filename) originalFilename = manifest.original_filename;
  if (!sourcePath && manifest.source_path) sourcePath = manifest.source_path;
  if (!sourceRevision && manifest.source_revision) sourceRevision = manifest.source_revision;

  let score = 0;
  const matchSnippets = [];

  // Match by ID
  if (searchId) {
    if (docId.toLowerCase().includes(searchId.toLowerCase())) {
      score += 100;
    } else {
      continue;
    }
  }

  // Match by query
  if (query) {
    const qLower = query.toLowerCase();
    
    // Exact ID or filename match
    if (docId.toLowerCase().includes(qLower)) score += 50;
    if (originalFilename.toLowerCase().includes(qLower)) score += 40;
    if (relPath.toLowerCase().includes(qLower)) score += 30;

    // Heading matches
    const lines = content.split(/\r?\n/);
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (line.toLowerCase().includes(qLower)) {
        if (/^#{1,6}\s+/.test(line) || /^-\s+.*\(line \d+\)/.test(line)) {
          score += 15;
          matchSnippets.push(`[Heading L${i+1}] ${line.trim()}`);
        } else if (matchSnippets.length < 3) {
          score += 5;
          matchSnippets.push(`[L${i+1}] ${line.trim().slice(0, 100)}`);
        }
      }
    }
  } else if (!searchId) {
    score = 1;
  }

  if (score > 0) {
    results.push({
      score,
      docId: docId || "UNINDEXED",
      filename: originalFilename || path.basename(file),
      normalizedPath: relPath,
      sourcePath: sourcePath || "N/A",
      sourceRevision: sourceRevision || "N/A",
      snippets: matchSnippets.slice(0, 3)
    });
  }
}

results.sort((a, b) => b.score - a.score);
const finalResults = results.slice(0, limit);

if (asJson) {
  console.log(JSON.stringify({ query: query || searchId, count: finalResults.length, results: finalResults }, null, 2));
} else {
  if (!finalResults.length) {
    console.log(`No matching documents found in KM vault for: "${query || searchId}"`);
  } else {
    console.log(`Found ${finalResults.length} matching document(s) in KM vault (${customVault}):\n`);
    finalResults.forEach((r, idx) => {
      console.log(`[${idx + 1}] ${r.docId} — ${r.filename}`);
      console.log(`    Normalized: ${r.normalizedPath}`);
      console.log(`    Source:     ${r.sourcePath} (${r.sourceRevision})`);
      if (r.snippets.length) {
        console.log(`    Matches:`);
        r.snippets.forEach(s => console.log(`      * ${s}`));
      }
      console.log();
    });
  }
}
