import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";
import { execFileSync } from "node:child_process";

function extractCodeHeadings(code, ext) {
  const headings = [];
  const lines = code.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (ext === ".py") {
      const m = /^(?:def|class|async def)\s+([a-zA-Z0-9_]+)/.exec(line);
      if (m) headings.push({ level: 2, title: `${line.trim().split('(')[0]}()`, line: i + 1 });
    } else if (ext === ".js" || ext === ".ts" || ext === ".mjs") {
      const m = /^(?:export\s+)?(?:async\s+)?(?:function\s+([a-zA-Z0-9_]+)|class\s+([a-zA-Z0-9_]+)|const\s+([a-zA-Z0-9_]+)\s*=\s*(?:async\s*)?\()/.exec(line);
      if (m) {
        const name = m[1] || m[2] || m[3];
        headings.push({ level: 2, title: `symbol: ${name}`, line: i + 1 });
      }
    }
  }
  return headings;
}

function processSingleFile(filePath, vault) {
  const src = path.resolve(filePath);
  if (!fs.existsSync(src) || !fs.statSync(src).isFile()) {
    console.error(`Input file not found or not a file: ${src}`);
    return null;
  }

  const raw = fs.readFileSync(src);
  const sha = crypto.createHash("sha256").update(raw).digest("hex");
  const docId = `DOC-${sha.slice(0, 12).toUpperCase()}`;
  const originalName = path.basename(src);
  const ext = path.extname(originalName).toLowerCase();
  const base = path.basename(originalName, ext)
    .normalize("NFKD")
    .replace(/[^\w.-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .toLowerCase() || "document";

  let markdown = "";
  let converter = "passthrough";
  let extractedHeadings = [];

  if (ext === ".md" || ext === ".markdown") {
    markdown = raw.toString("utf8");
    converter = "passthrough";
  } else if (ext === ".txt") {
    markdown = `# ${path.basename(originalName, ext)}\n\n${raw.toString("utf8")}`;
    converter = "passthrough";
  } else if (ext === ".ipynb") {
    converter = "notebook-parser";
    try {
      const nb = JSON.parse(raw.toString("utf8"));
      const cells = nb.cells || [];
      const parts = [`# Jupyter Notebook: ${originalName}\n`];
      cells.forEach((cell, idx) => {
        const cellNum = idx + 1;
        const cellSource = Array.isArray(cell.source) ? cell.source.join("") : (cell.source || "");
        if (cell.cell_type === "markdown") {
          parts.push(`\n## Cell ${cellNum} (Markdown)\n\n${cellSource}`);
          extractedHeadings.push({ level: 2, title: `Cell ${cellNum} (Markdown)`, line: parts.join("\n").split("\n").length });
        } else if (cell.cell_type === "code") {
          parts.push(`\n## Cell ${cellNum} (Code)\n\n\`\`\`python\n${cellSource}\n\`\`\``);
          extractedHeadings.push({ level: 2, title: `Cell ${cellNum} (Code)`, line: parts.join("\n").split("\n").length });
        }
      });
      markdown = parts.join("\n");
    } catch (e) {
      markdown = `# ${originalName}\n\n\`\`\`json\n${raw.toString("utf8")}\n\`\`\``;
    }
  } else if ([".py", ".js", ".mjs", ".cjs", ".ts", ".html", ".css", ".sh", ".yml", ".yaml", ".json"].includes(ext)) {
    converter = "code-converter";
    const lang = ext.replace(".", "");
    const codeText = raw.toString("utf8");
    const symHeadings = extractCodeHeadings(codeText, ext);
    markdown = `# Code: ${originalName}\n\nLanguage: \`${lang}\`\nSize: \`${raw.length} bytes\`\n\n\`\`\`${lang}\n${codeText}\n\`\`\``;
    extractedHeadings = symHeadings;
  } else {
    converter = "firecrawl-anydoc";
    const tmp = path.join(os.tmpdir(), `${docId}.md`);
    try {
      execFileSync("anydoc", [src, "-o", tmp], { stdio: "inherit" });
      markdown = fs.readFileSync(tmp, "utf8");
    } catch (err) {
      console.warn(`anydoc failed on ${originalName}, falling back to text representation: ${err.message}`);
      markdown = `# Document: ${originalName}\n\n${raw.toString("utf8", 0, Math.min(raw.length, 50000))}`;
      converter = "fallback-text";
    } finally {
      fs.rmSync(tmp, { force: true });
    }
  }

  const headings = [];
  for (const [i, line] of markdown.split(/\r?\n/).entries()) {
    const m = /^(#{1,6})\s+(.+?)\s*$/.exec(line);
    if (m) headings.push({ level: m[1].length, title: m[2], line: i + 1 });
  }
  if (!headings.length) {
    headings.push({ level: 1, title: base, line: 1 });
  }

  const sourceDir = path.join(vault, "source", "imported", docId);
  const knowledgeDir = path.join(vault, "knowledge", "imported");
  const metaDir = path.join(vault, ".km", "ingest");
  fs.mkdirSync(sourceDir, { recursive: true });
  fs.mkdirSync(knowledgeDir, { recursive: true });
  fs.mkdirSync(metaDir, { recursive: true });

  const sourceRel = `source/imported/${docId}/${originalName}`;
  const knowledgeRel = `knowledge/imported/${docId}-${base}.md`;
  const indexRel = `knowledge/imported/${docId}-${base}.index.md`;
  const importedAt = new Date().toISOString();

  function atomicWrite(dest, content) {
    const tmp = `${dest}.tmp-${process.pid}-${Math.random().toString(36).slice(2, 6)}`;
    fs.writeFileSync(tmp, content);
    fs.renameSync(tmp, dest);
  }

  fs.copyFileSync(src, path.join(sourceDir, originalName));

  const frontmatter = [
    "---",
    `id: ${docId}`,
    "type: imported-document",
    "authority: derived",
    `source: ${JSON.stringify(sourceRel)}`,
    `source_revision: "sha256:${sha}"`,
    `original_filename: ${JSON.stringify(originalName)}`,
    `imported_at: ${JSON.stringify(importedAt)}`,
    "generated_by: km-demo-ingest",
    "---",
    "",
  ].join("\n");
  atomicWrite(path.join(vault, knowledgeRel), frontmatter + markdown.trim() + "\n");

  const treeLines = headings.map(h =>
    `${"  ".repeat(Math.max(0, h.level - 1))}- ${h.title} (line ${h.line})`
  );
  const indexMd = [
    "---",
    `id: ${docId}-INDEX`,
    "type: document-structure-index",
    "authority: derived",
    `source: ${JSON.stringify(knowledgeRel)}`,
    `source_revision: "sha256:${sha}"`,
    `imported_at: ${JSON.stringify(importedAt)}`,
    "---",
    "",
    `# Structure — ${originalName}`,
    "",
    `- Document ID: \`${docId}\``,
    `- Original: \`${sourceRel}\``,
    `- Normalized: \`${knowledgeRel}\``,
    `- SHA-256: \`${sha}\``,
    "",
    "## Heading tree",
    "",
    ...treeLines,
    "",
  ].join("\n");
  atomicWrite(path.join(vault, indexRel), indexMd);

  const manifest = {
    id: docId,
    original_filename: originalName,
    source_path: sourceRel,
    normalized_path: knowledgeRel,
    structure_path: indexRel,
    source_revision: `sha256:${sha}`,
    imported_at: importedAt,
    heading_count: headings.length,
    converter: converter,
  };
  atomicWrite(path.join(metaDir, `${docId}.json`), JSON.stringify(manifest, null, 2) + "\n");
  return manifest;
}

function walkDir(dir) {
  const files = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name.startsWith(".") || entry.name === "node_modules" || entry.name === "__pycache__") continue;
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...walkDir(fullPath));
    } else if (entry.isFile()) {
      files.push(fullPath);
    }
  }
  return files;
}

const input = process.argv[2];
if (!input) {
  console.error("Usage: ingest.mjs <file|directory>");
  process.exit(2);
}

const vault = process.env.VAULT_PATH || "/vault";
const targetPath = path.resolve(input);
if (!fs.existsSync(targetPath)) {
  console.error(`Target not found: ${targetPath}`);
  process.exit(2);
}

const stat = fs.statSync(targetPath);
if (stat.isDirectory()) {
  const files = walkDir(targetPath);
  console.log(`Ingesting directory ${targetPath} (${files.length} files)...`);
  const manifests = [];
  for (const file of files) {
    const m = processSingleFile(file, vault);
    if (m) manifests.push(m);
  }
  console.log(JSON.stringify({ directory: targetPath, count: manifests.length, documents: manifests }, null, 2));
} else {
  const manifest = processSingleFile(targetPath, vault);
  if (manifest) {
    console.log(JSON.stringify(manifest, null, 2));
  } else {
    process.exit(1);
  }
}
