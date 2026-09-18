import child_process from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

let visibleWidth: (s: string) => number;
let truncateToWidth: (s: string, w: number, ellipsis?: string) => string;

try {
  const tui = require("@earendil-works/pi-tui");
  visibleWidth = tui.visibleWidth;
  truncateToWidth = tui.truncateToWidth;
} catch {
  visibleWidth = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, "").length;
  truncateToWidth = (s: string, w: number, el = "...") => {
    const raw = s.replace(/\x1b\[[0-9;]*m/g, "");
    return raw.length > w ? raw.slice(0, Math.max(0, w - el.length)) + el : s;
  };
}

let CustomEditorBase: any;
let createReadToolFn: any;
try {
  const agent = require("@earendil-works/pi-coding-agent");
  CustomEditorBase = agent.CustomEditor;
  createReadToolFn = agent.createReadTool;
} catch {
  try {
    const agent = require("/nix/store/m58mjsdjgk3zrwar1ckw2lb4q241l7j9-pi-coding-agent-0.85.1/lib/node_modules/pi-monorepo/dist/index.js");
    CustomEditorBase = agent.CustomEditor;
    createReadToolFn = agent.createReadTool;
  } catch {}
}

let ContainerClass: any;
let TextClass: any;
try {
  const tui = require("@earendil-works/pi-tui");
  ContainerClass = tui.Container;
  TextClass = tui.Text;
} catch {}

// Transparent stream interceptor for Merge Gateway to map "thinking": delta to "reasoning_content":
// so Pi's built-in reasoning engine can display the thinking stream in real-time.
if (!(globalThis as any).__mg_fetch_intercepted__) {
  (globalThis as any).__mg_fetch_intercepted__ = true;
  const originalFetch = globalThis.fetch;

  globalThis.fetch = async function (input: any, init?: any) {
    const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input?.url;
    const res = await originalFetch(input, init);

    if (url && url.includes("api-gateway.merge.dev") && res.body) {
      const contentType = res.headers.get("content-type") || "";
      if (contentType.includes("text/event-stream")) {
        const textDecoder = new TextDecoder();
        const textEncoder = new TextEncoder();
        let buffer = "";

        const transform = new TransformStream({
          transform(chunk, controller) {
            buffer += textDecoder.decode(chunk, { stream: true });
            const lines = buffer.split("\n");
            buffer = lines.pop() || "";
            for (const line of lines) {
              if (line.startsWith("data:") && line.includes("\"thinking\":")) {
                controller.enqueue(textEncoder.encode(line.replace(/"thinking":/g, "\"reasoning_content\":") + "\n"));
              } else {
                controller.enqueue(textEncoder.encode(line + "\n"));
              }
            }
          },
          flush(controller) {
            if (buffer.length > 0) {
              if (buffer.startsWith("data:") && buffer.includes("\"thinking\":")) {
                controller.enqueue(textEncoder.encode(buffer.replace(/"thinking":/g, "\"reasoning_content\":")));
              } else {
                controller.enqueue(textEncoder.encode(buffer));
              }
            }
          },
        });

        const transformedBody = res.body.pipeThrough(transform);
        return new Response(transformedBody, {
          status: res.status,
          statusText: res.statusText,
          headers: res.headers,
        });
      } else if (contentType.includes("application/json")) {
        const text = await res.text();
        const replaced = text.replace(/"thinking":/g, "\"reasoning_content\":");
        return new Response(replaced, {
          status: res.status,
          statusText: res.statusText,
          headers: res.headers,
        });
      }
    }

    return res;
  };
}

function formatTokens(count: number): string {
  if (!count || count < 0) return "0";
  if (count < 1000) return count.toString();
  if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
  if (count < 1000000) return `${Math.round(count / 1000)}k`;
  if (count < 10000000) return `${(count / 1000000).toFixed(1)}M`;
  return `${Math.round(count / 1000000)}M`;
}

function formatCwdForFooter(cwd: string, home?: string): string {
  if (!home) return cwd;
  const resolvedCwd = path.resolve(cwd);
  const resolvedHome = path.resolve(home);
  const relativeToHome = path.relative(resolvedHome, resolvedCwd);
  const isInsideHome =
    relativeToHome === "" ||
    (relativeToHome !== ".." && !relativeToHome.startsWith(`..${path.sep}`) && !path.isAbsolute(relativeToHome));
  if (!isInsideHome) return cwd;
  return relativeToHome === "" ? "~" : `~${path.sep}${relativeToHome}`;
}

interface GitStatus {
  branch: string;
  ahead: number;
  behind: number;
  staged: number;
  modified: number;
  untracked: number;
}

let cachedGitStatus: { cwd: string; time: number; status: GitStatus | null } = {
  cwd: "",
  time: 0,
  status: null,
};

function getGitStatusSync(cwd: string): GitStatus | null {
  const now = Date.now();
  if (cachedGitStatus.cwd === cwd && now - cachedGitStatus.time < 1000) {
    return cachedGitStatus.status;
  }

  try {
    const out = child_process.execFileSync("git", ["status", "--porcelain=v2", "--branch"], {
      cwd,
      timeout: 500,
      stdio: ["ignore", "pipe", "ignore"],
      encoding: "utf-8",
    });

    let branch = "";
    let ahead = 0;
    let behind = 0;
    let staged = 0;
    let modified = 0;
    let untracked = 0;

    for (const line of out.split("\n")) {
      if (line.startsWith("# branch.head ")) {
        branch = line.slice(14).trim();
      } else if (line.startsWith("# branch.ab ")) {
        const parts = line.slice(12).split(" ");
        ahead = parseInt(parts[0].replace("+", ""), 10) || 0;
        behind = Math.abs(parseInt(parts[1].replace("-", ""), 10)) || 0;
      } else if (line.startsWith("1 ") || line.startsWith("2 ")) {
        const xy = line.slice(2, 4);
        if (xy[0] !== ".") staged++;
        if (xy[1] !== ".") modified++;
      } else if (line.startsWith("? ")) {
        untracked++;
      }
    }

    const status: GitStatus = { branch, ahead, behind, staged, modified, untracked };
    cachedGitStatus = { cwd, time: now, status };
    return status;
  } catch {
    cachedGitStatus = { cwd, time: now, status: null };
    return null;
  }
}

function formatGitBranchAndStatus(cwd: string, fallbackBranch: string | null, theme: any): string {
  const status = getGitStatusSync(cwd);
  const branch = status?.branch || fallbackBranch;
  if (!branch || branch === "(none)") return "";

  const branchDisplay = branch === "(detached)" ? "detached" : branch;
  const branchFormatted = theme.fg("accent", branchDisplay);

  const parts: string[] = [];
  if (status) {
    if (status.ahead > 0) parts.push(theme.fg("accent", `⇡${status.ahead}`));
    if (status.behind > 0) parts.push(theme.fg("accent", `⇣${status.behind}`));
    if (status.staged > 0) parts.push(theme.fg("success", `+${status.staged}`));
    if (status.modified > 0) parts.push(theme.fg("warning", `*${status.modified}`));
    if (status.untracked > 0) parts.push(theme.fg("dim", `?${status.untracked}`));
  }

  const statusSuffix = parts.length > 0 ? ` ${parts.join(" ")}` : "";
  return `${theme.fg("dim", "(")}${branchFormatted}${statusSuffix}${theme.fg("dim", ")")}`;
}

function renderStatusBarLine(ctx: any, pi: any, theme: any, width: number, extStatuses?: ReadonlyMap<string, string>): string {
  const cwd = ctx.cwd || process.cwd();
  const pwd = formatCwdForFooter(cwd, os.homedir());
  const gitStr = formatGitBranchAndStatus(cwd, null, theme);

  // Context usage
  const contextUsage = ctx.getContextUsage?.();
  const contextWindow = contextUsage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
  const contextPercentValue = contextUsage?.percent ?? 0;
  const contextPercent =
    contextUsage?.percent !== null && contextUsage?.percent !== undefined
      ? contextPercentValue.toFixed(1)
      : "0.0";
  const autoIndicator = " (auto)";
  const contextPercentDisplay = `${contextPercent}%/${formatTokens(contextWindow)}${autoIndicator}`;

  let contextPercentStr: string;
  if (contextPercentValue > 90) {
    contextPercentStr = theme.fg("error", contextPercentDisplay);
  } else if (contextPercentValue > 70) {
    contextPercentStr = theme.fg("warning", contextPercentDisplay);
  } else {
    contextPercentStr = theme.fg("dim", contextPercentDisplay);
  }

  // Model & thinking level
  const modelObj = ctx.model;
  const provider = modelObj?.provider || "merge-gateway";
  const modelId = modelObj?.id || "deepseek/deepseek-v4.1-flash";

  let thinkingLevel: string | undefined;
  try {
    thinkingLevel = pi.getThinkingLevel?.();
  } catch {}

  if (!thinkingLevel || thinkingLevel === "off") {
    if (modelObj?.reasoning) {
      thinkingLevel = "high";
    }
  }

  let rightSide: string;
  if (modelObj?.reasoning && thinkingLevel && thinkingLevel !== "off") {
    rightSide = `${theme.fg("dim", `(${provider})`)} ${theme.fg("text", modelId)} ${theme.fg("dim", "•")} ${theme.fg("accent", thinkingLevel)}`;
  } else {
    rightSide = `${theme.fg("dim", `(${provider})`)} ${theme.fg("text", modelId)}`;
  }

  // Left side
  const leftParts = [
    theme.fg("dim", pwd),
    gitStr,
    contextPercentStr,
  ].filter(Boolean);
  const leftSide = leftParts.join(" ");

  // Extension statuses (e.g. LSP)
  let extText = "";
  if (extStatuses && extStatuses.size > 0) {
    const sorted = Array.from(extStatuses.values()).map((t: any) => String(t).trim()).filter(Boolean);
    if (sorted.length > 0) {
      extText = sorted.join(" ");
    }
  }

  const leftWidth = visibleWidth(leftSide);
  const rightWidth = visibleWidth(rightSide);
  const extWidth = extText ? visibleWidth(extText) : 0;
  const minPad = 2;

  let fullLine: string;
  if (leftWidth + minPad + rightWidth <= width) {
    if (extText && leftWidth + extWidth + minPad + rightWidth + 3 <= width) {
      const space = width - leftWidth - extWidth - rightWidth - 3;
      const pad = " ".repeat(Math.max(1, space));
      fullLine = `${leftSide} ${theme.fg("dim", "·")} ${extText}${pad}${rightSide}`;
    } else {
      const pad = " ".repeat(Math.max(minPad, width - leftWidth - rightWidth));
      fullLine = `${leftSide}${pad}${rightSide}`;
    }
  } else {
    const availableForRight = width - leftWidth - minPad;
    if (availableForRight > 15) {
      const truncatedRight = truncateToWidth(rightSide, availableForRight, "");
      const pad = " ".repeat(Math.max(1, width - leftWidth - visibleWidth(truncatedRight)));
      fullLine = `${leftSide}${pad}${truncatedRight}`;
    } else {
      fullLine = truncateToWidth(leftSide, width, theme.fg("dim", "..."));
    }
  }

  return fullLine;
}

async function searchDuckDuckGo(query: string, limit = 5): Promise<Array<{ title: string; url: string; snippet: string }>> {
  const url = `https://html.duckduckgo.com/html/?q=${encodeURIComponent(query)}`;
  const res = await fetch(url, {
    headers: {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "Accept-Language": "en-US,en;q=0.5",
    },
  });
  if (!res.ok) {
    throw new Error(`Search request failed with status ${res.status}`);
  }
  const html = await res.text();
  const results: Array<{ title: string; url: string; snippet: string }> = [];

  const titleRegex = /<h2 class="result__title">\s*<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/g;
  const snippetRegex = /<a[^>]*class="result__snippet"[^>]*>([\s\S]*?)<\/a>/g;

  const titles: Array<{ title: string; url: string }> = [];
  let m: RegExpExecArray | null;
  while ((m = titleRegex.exec(html)) !== null) {
    const rawHref = m[1];
    const title = m[2]
      .replace(/<[^>]+>/g, "")
      .replace(/&amp;/g, "&")
      .replace(/&#x27;/g, "'")
      .replace(/&quot;/g, '"')
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .trim();
    let cleanUrl = rawHref;
    if (rawHref.includes("uddg=")) {
      const match = rawHref.match(/uddg=([^&]+)/);
      if (match) cleanUrl = decodeURIComponent(match[1]);
    }
    titles.push({ title, url: cleanUrl });
  }

  const snippets: string[] = [];
  while ((m = snippetRegex.exec(html)) !== null) {
    const snippet = m[1]
      .replace(/<[^>]+>/g, "")
      .replace(/&amp;/g, "&")
      .replace(/&#x27;/g, "'")
      .replace(/&quot;/g, '"')
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .trim();
    snippets.push(snippet);
  }

  const maxItems = Math.max(1, Math.min(limit, 10));
  for (let i = 0; i < Math.min(titles.length, maxItems); i++) {
    results.push({
      title: titles[i].title,
      url: titles[i].url,
      snippet: snippets[i] || "",
    });
  }

  return results;
}

async function fetchWebPage(url: string, maxLength = 8000): Promise<string> {
  const res = await fetch(url, {
    headers: {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Accept": "text/html,text/plain;q=0.9,*/*;q=0.8",
    },
  });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}: ${res.statusText}`);
  }
  let html = await res.text();
  html = html.replace(/<head[\s\S]*?<\/head>/gi, "");
  html = html.replace(/<script[\s\S]*?<\/script>/gi, "");
  html = html.replace(/<style[\s\S]*?<\/style>/gi, "");
  html = html.replace(/<nav[\s\S]*?<\/nav>/gi, "");
  html = html.replace(/<footer[\s\S]*?<\/footer>/gi, "");

  let text = html.replace(/<h[1-6][^>]*>([\s\S]*?)<\/h[1-6]>/gi, "\n\n# $1\n");
  text = text.replace(/<p[^>]*>([\s\S]*?)<\/p>/gi, "\n\n$1\n");
  text = text.replace(/<li[^>]*>([\s\S]*?)<\/li>/gi, "\n• $1");
  text = text.replace(/<br\s*[\/]?>/gi, "\n");
  text = text.replace(/<[^>]+>/g, "");
  text = text
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#x27;/g, "'")
    .replace(/&nbsp;/g, " ");

  text = text
    .split("\n")
    .map((l) => l.trim())
    .filter((l, i, arr) => l.length > 0 || (i > 0 && arr[i - 1].length > 0))
    .join("\n");

  if (text.length > maxLength) {
    text = text.slice(0, maxLength) + `\n\n... [truncated, ${text.length} total chars]`;
  }
  return text;
}

export default function (pi: any) {
  // Compact 1-line read tool renderer with batch & parallel support
  if (createReadToolFn && ContainerClass && TextClass) {
    try {
      const originalRead = createReadToolFn(process.cwd());
      const readParams = {
        ...originalRead.parameters,
        properties: {
          ...originalRead.parameters?.properties,
          paths: {
            type: "array",
            items: { type: "string" },
            description: "Optional array of file paths to read concurrently in parallel in a single call instead of one-by-one.",
          },
        },
      };

      pi.registerTool({
        name: "read",
        label: "read",
        description: "Read the contents of a file or multiple files in parallel. When reading multiple files, pass paths: [path1, path2, ...] to read them all concurrently in a single operation.",
        parameters: readParams,
        renderShell: "self",

        async execute(toolCallId: string, params: any, signal: any, onUpdate: any, context: any) {
          if (Array.isArray(params?.paths) && params.paths.length > 0) {
            const cwd = context?.cwd || process.cwd();
            const results = await Promise.all(
              params.paths.map(async (p: string) => {
                const abs = path.resolve(cwd, p);
                try {
                  const data = await fs.promises.readFile(abs, "utf-8");
                  const lines = data.split("\n");
                  return { path: p, ok: true, text: data, lineCount: lines.length };
                } catch (err: any) {
                  return { path: p, ok: false, error: err?.message || String(err) };
                }
              })
            );

            let totalLines = 0;
            const textParts: string[] = [];
            for (const r of results) {
              if (r.ok) {
                totalLines += r.lineCount;
                textParts.push(`--- ${r.path} (${r.lineCount} lines) ---\n${r.text}`);
              } else {
                textParts.push(`--- ${r.path} (ERROR) ---\nError reading file: ${r.error}`);
              }
            }

            return {
              content: [{ type: "text", text: textParts.join("\n\n") }],
              details: { paths: params.paths, lineCount: totalLines, results },
            };
          }

          return (originalRead.execute as any)(toolCallId, params, signal, onUpdate, context);
        },

        renderCall(args: any, theme: any, context: any) {
          const textComp = (context.lastComponent as any) ?? new TextClass("", 0, 0);
          const state = context.state;

          if (Array.isArray(args?.paths) && args.paths.length > 0) {
            const countFiles = args.paths.length;
            const shortNames = args.paths.slice(0, 3).map((p: string) => path.basename(p)).join(", ");
            const displayNames = countFiles > 3 ? `${shortNames}, +${countFiles - 3} more` : shortNames;

            if (state?.result) {
              const totalLines = state.lineCount ?? 0;
              textComp.setText(
                `${theme.fg("success", "✓")} ${theme.fg("toolTitle", theme.bold("read"))} ${theme.fg("accent", `${countFiles} files`)} ${theme.fg("dim", `(${displayNames}) · ${totalLines} lines`)}`
              );
            } else {
              textComp.setText(
                `${theme.fg("dim", "⠋")} ${theme.fg("toolTitle", theme.bold("read"))} ${theme.fg("accent", `${countFiles} files`)} ${theme.fg("dim", `(${displayNames})`)}`
              );
            }
            return textComp;
          }

          const filePath = args?.path || "";
          const rangeParts: string[] = [];
          if (args?.offset) rangeParts.push(`offset=${args.offset}`);
          if (args?.limit) rangeParts.push(`limit=${args.limit}`);
          const rangeStr = rangeParts.length > 0 ? ` [${rangeParts.join(",")}]` : "";

          if (state?.result) {
            if (state.isError) {
              const err = state.result.content?.[0]?.text?.split("\n")[0] || "error";
              textComp.setText(
                `${theme.fg("error", "✗")} ${theme.fg("toolTitle", theme.bold("read"))} ${theme.fg("error", filePath)}${rangeStr} ${theme.fg("dim", `(${err})`)}`
              );
            } else {
              const count = state.lineCount ?? 0;
              const trunc = state.truncated ? theme.fg("warning", " [truncated]") : "";
              textComp.setText(
                `${theme.fg("success", "✓")} ${theme.fg("toolTitle", theme.bold("read"))} ${theme.fg("accent", filePath)}${rangeStr} ${theme.fg("dim", `(${count} lines)`)}${trunc}`
              );
            }
          } else {
            textComp.setText(
              `${theme.fg("dim", "⠋")} ${theme.fg("toolTitle", theme.bold("read"))} ${theme.fg("accent", filePath)}${rangeStr}`
            );
          }

          return textComp;
        },

        renderResult(result: any, { expanded, isPartial }: any, theme: any, context: any) {
          const state = context.state;
          const content = result?.content?.[0];
          const isError = context.isError || (content?.type === "text" && content.text.startsWith("Error"));

          let lineCount = 0;
          if (content?.type === "text") {
            lineCount = content.text.split("\n").length;
          }

          const details = result?.details;
          const wasTruncated = !!details?.truncation?.truncated;

          const needsInvalidate =
            !state.result ||
            state.lineCount !== lineCount ||
            state.isError !== isError ||
            state.isPartial !== isPartial;

          state.result = result;
          state.isError = isError;
          state.lineCount = lineCount;
          state.truncated = wasTruncated;
          state.isPartial = isPartial;

          if (needsInvalidate) {
            context.invalidate();
          }

          if (!expanded || isPartial || isError) {
            return new ContainerClass();
          }

          if (content?.type === "text") {
            const lines = content.text.split("\n").slice(0, 15);
            let preview = "";
            for (const l of lines) {
              preview += (preview ? "\n" : "") + theme.fg("dim", `  ${l}`);
            }
            if (lineCount > 15) {
              preview += "\n" + theme.fg("muted", `  ... ${lineCount - 15} more lines`);
            }
            return new TextClass(preview, 0, 0);
          }

          return new ContainerClass();
        },
      });
    } catch {}
  }

  // Zero-config Web Search Tool (DuckDuckGo HTML)
  if (ContainerClass && TextClass) {
    try {
      pi.registerTool({
        name: "web_search",
        label: "web search",
        description: "Search the web using DuckDuckGo. Returns titles, URLs, and snippets of top search results. Pass query string and optional limit (1-10, default 5).",
        parameters: {
          type: "object",
          properties: {
            query: { type: "string", description: "Search terms or question to look up on the web" },
            limit: { type: "number", description: "Maximum number of search results (1-10, default 5)" },
          },
          required: ["query"],
        },
        renderShell: "self",

        async execute(_toolCallId: string, params: any) {
          const query = params?.query?.trim();
          if (!query) {
            return {
              content: [{ type: "text", text: "Error: query string cannot be empty" }],
              details: { count: 0, error: "Empty query" },
              isError: true,
            };
          }

          try {
            const results = await searchDuckDuckGo(query, params.limit || 5);
            if (results.length === 0) {
              return {
                content: [{ type: "text", text: `No search results found for: "${query}"` }],
                details: { count: 0, query },
              };
            }

            const formatted = results
              .map((r, i) => `${i + 1}. [${r.title}](${r.url})\n   ${r.snippet}`)
              .join("\n\n");

            return {
              content: [{ type: "text", text: formatted }],
              details: { count: results.length, query, results },
            };
          } catch (err: any) {
            return {
              content: [{ type: "text", text: `Search error: ${err?.message || String(err)}` }],
              details: { count: 0, error: err?.message || String(err) },
              isError: true,
            };
          }
        },

        renderCall(args: any, theme: any, context: any) {
          const textComp = (context.lastComponent as any) ?? new TextClass("", 0, 0);
          const state = context.state;
          const query = args?.query ? `"${args.query}"` : "...";

          if (state?.result) {
            if (state.isError) {
              const err = state.errorMessage || "error";
              textComp.setText(
                `${theme.fg("error", "✗")} ${theme.fg("toolTitle", theme.bold("web_search"))} ${theme.fg("error", query)} ${theme.fg("dim", `(${err})`)}`
              );
            } else {
              const count = state.count ?? 0;
              textComp.setText(
                `${theme.fg("success", "✓")} ${theme.fg("toolTitle", theme.bold("web_search"))} ${theme.fg("accent", query)} ${theme.fg("dim", `(${count} results)`)}`
              );
            }
          } else {
            textComp.setText(
              `${theme.fg("dim", "⠋")} ${theme.fg("toolTitle", theme.bold("web_search"))} ${theme.fg("accent", query)}`
            );
          }

          return textComp;
        },

        renderResult(result: any, { expanded, isPartial }: any, theme: any, context: any) {
          const state = context.state;
          const details = result?.details;
          const isError = context.isError || result?.isError || false;
          const count = details?.count ?? 0;
          const errorMessage = details?.error;

          const needsInvalidate =
            !state.result ||
            state.count !== count ||
            state.isError !== isError ||
            state.isPartial !== isPartial;

          state.result = result;
          state.count = count;
          state.isError = isError;
          state.errorMessage = errorMessage;
          state.isPartial = isPartial;

          if (needsInvalidate) {
            context.invalidate();
          }

          if (!expanded || isPartial || isError) {
            return new ContainerClass();
          }

          const results = details?.results as Array<{ title: string; url: string; snippet: string }> | undefined;
          if (results && results.length > 0) {
            let body = "";
            for (const r of results.slice(0, 5)) {
              body += (body ? "\n" : "") + theme.fg("accent", `• ${r.title}`) + "\n  " + theme.fg("dim", r.url);
            }
            return new TextClass(body, 0, 0);
          }

          return new ContainerClass();
        },
      });

      // Zero-config Web Fetch Tool
      pi.registerTool({
        name: "web_fetch",
        label: "web fetch",
        description: "Fetch and extract readable plain text/markdown content from a web page URL. Automatically strips HTML boilerplate, scripts, and navigation.",
        parameters: {
          type: "object",
          properties: {
            url: { type: "string", description: "The full web page URL (http or https) to fetch" },
            maxLength: { type: "number", description: "Maximum number of characters to return (default 8000)" },
          },
          required: ["url"],
        },
        renderShell: "self",

        async execute(_toolCallId: string, params: any) {
          const targetUrl = params?.url?.trim();
          if (!targetUrl) {
            return {
              content: [{ type: "text", text: "Error: URL cannot be empty" }],
              details: { chars: 0, error: "Empty URL" },
              isError: true,
            };
          }

          try {
            const text = await fetchWebPage(targetUrl, params.maxLength || 8000);
            return {
              content: [{ type: "text", text }],
              details: { chars: text.length, url: targetUrl },
            };
          } catch (err: any) {
            return {
              content: [{ type: "text", text: `Fetch error: ${err?.message || String(err)}` }],
              details: { chars: 0, error: err?.message || String(err) },
              isError: true,
            };
          }
        },

        renderCall(args: any, theme: any, context: any) {
          const textComp = (context.lastComponent as any) ?? new TextClass("", 0, 0);
          const state = context.state;
          const urlStr = args?.url || "...";

          if (state?.result) {
            if (state.isError) {
              const err = state.errorMessage || "error";
              textComp.setText(
                `${theme.fg("error", "✗")} ${theme.fg("toolTitle", theme.bold("web_fetch"))} ${theme.fg("error", urlStr)} ${theme.fg("dim", `(${err})`)}`
              );
            } else {
              const chars = state.chars ?? 0;
              textComp.setText(
                `${theme.fg("success", "✓")} ${theme.fg("toolTitle", theme.bold("web_fetch"))} ${theme.fg("accent", urlStr)} ${theme.fg("dim", `(${chars} chars)`)}`
              );
            }
          } else {
            textComp.setText(
              `${theme.fg("dim", "⠋")} ${theme.fg("toolTitle", theme.bold("web_fetch"))} ${theme.fg("accent", urlStr)}`
            );
          }

          return textComp;
        },

        renderResult(result: any, { expanded, isPartial }: any, _theme: any, context: any) {
          const state = context.state;
          const details = result?.details;
          const isError = context.isError || result?.isError || false;
          const chars = details?.chars ?? 0;
          const errorMessage = details?.error;

          const needsInvalidate =
            !state.result ||
            state.chars !== chars ||
            state.isError !== isError ||
            state.isPartial !== isPartial;

          state.result = result;
          state.chars = chars;
          state.isError = isError;
          state.errorMessage = errorMessage;
          state.isPartial = isPartial;

          if (needsInvalidate) {
            context.invalidate();
          }

          return new ContainerClass();
        },
      });
    } catch {}
  }

  pi.on("before_agent_start", async (event: any) => {
    const guidance = `
## Tool Calling & Web Search Guidelines
- Web Search & Fetch: You have \`web_search\` and \`web_fetch\` available. Use \`web_search\` to search the internet (via DuckDuckGo) for real-time information, documentation, or links. Use \`web_fetch\` with any URL to extract clean readable web page content.
- Fast Parallel Reading: When inspecting multiple files, do NOT read them one-by-one sequentially across turns. Either pass \`paths: ["file1", "file2", ...]\` to \`read\` to read them concurrently in a single call, or issue multiple parallel \`read\` tool calls in the same turn.
- Subagents: For broad codebase reconnaissance, multi-file reviews, or large searches, delegate to the \`subagent\` tool (using \`agent: "scout"\` or parallel \`tasks: [...]\`) with isolated context.
`;
    return {
      systemPrompt: `${event.systemPrompt}\n${guidance}`,
    };
  });

  // Ensure essential environment variables and PATH for language servers & MCP
  try {
    const home = os.homedir();
    const extraPaths = [
      path.join(home, ".npm-global", "bin"),
      path.join(home, "go", "bin"),
      path.join(home, ".local", "bin"),
      path.join(home, ".cargo", "bin"),
    ];
    const currentPaths = (process.env.PATH || "").split(path.delimiter);
    for (const p of extraPaths) {
      if (!currentPaths.includes(p) && fs.existsSync(p)) {
        process.env.PATH = `${p}${path.delimiter}${process.env.PATH || ""}`;
      }
    }

    if (!process.env.CONTEXT7_API_KEY && fs.existsSync("/run/secrets/context7-api-key")) {
      process.env.CONTEXT7_API_KEY = fs.readFileSync("/run/secrets/context7-api-key", "utf-8").trim();
    }
  } catch {}

  pi.on("turn_start", async () => {
    cachedGitStatus.time = 0;
  });
  pi.on("turn_end", async () => {
    cachedGitStatus.time = 0;
  });
  pi.on("tool_execution_end", async () => {
    cachedGitStatus.time = 0;
  });

  pi.on("session_start", async (_event: any, ctx: any) => {
    if (ctx?.mode !== "tui") {
      return;
    }

    // Ensure default thinking level is set to "high" for reasoning models
    try {
      if (ctx.model?.reasoning && pi.getThinkingLevel) {
        const curr = pi.getThinkingLevel();
        if (!curr || curr === "off") {
          pi.setThinkingLevel("high");
        }
      }
    } catch {}

    const home = os.homedir();
    const skillsDir = path.join(home, ".agents", "skills");
    let skillCount = 0;
    try {
      if (fs.existsSync(skillsDir)) {
        skillCount = fs.readdirSync(skillsDir, { withFileTypes: true }).filter(
          (d) => d.isDirectory() || d.isSymbolicLink()
        ).length;
      }
    } catch {}

    const hasContext = (() => {
      try {
        let curr = ctx.cwd || process.cwd();
        while (curr && curr !== path.dirname(curr)) {
          if (
            fs.existsSync(path.join(curr, "AGENTS.md")) ||
            fs.existsSync(path.join(curr, "CLAUDE.md"))
          ) {
            return true;
          }
          curr = path.dirname(curr);
        }
      } catch {}
      return false;
    })();

    // Custom Minimal Header at top
    ctx.ui.setHeader((_tui: any, theme: any) => {
      return {
        render(_width: number): string[] {
          const dot = theme.fg("dim", " · ");
          const piTag = theme.bold(theme.fg("accent", "π pi"));
          const ver = theme.fg("dim", "v0.85.1");

          const modelObj = ctx.model;
          const modelText = modelObj
            ? `${theme.fg("text", modelObj.id)} ${theme.fg("dim", `(${modelObj.provider})`)}`
            : theme.fg("dim", "no model");

          const skillsText = skillCount > 0 ? theme.fg("dim", `${skillCount} skills`) : "";
          const ctxText = hasContext ? theme.fg("accent", "AGENTS.md") : "";

          const line1Parts = [
            `${piTag} ${ver}`,
            modelText,
            skillsText,
            ctxText,
          ].filter(Boolean);
          const line1 = line1Parts.join(dot);

          return [line1];
        },
        invalidate() {},
      };
    });

    // Custom Editor: removes top border, keeps only a thin dim bottom line
    if (CustomEditorBase) {
      class ThinEditor extends CustomEditorBase {
        renderTopBorder(): string {
          return "";
        }

        protected renderBottomBorder(width: number, hiddenLineCount: number): string {
          const border = hiddenLineCount > 0 ? `↓ ${hiddenLineCount} more ` : "─".repeat(width);
          const line = border.length < width ? border + "─".repeat(width - border.length) : border;
          return this.theme?.fg ? this.theme.fg("dim", line) : `\x1b[90m${line}\x1b[0m`;
        }

        render(width: number): string[] {
          const lines = super.render(width);
          if (lines.length > 0 && lines[0] === "") {
            lines.shift();
          }
          return lines;
        }
      }

      ctx.ui.setEditorComponent((tui: any, editorTheme: any, kb: any) => {
        return new ThinEditor(tui, editorTheme, kb, { embedWorkingStatus: true });
      });
    }

    // Status Bar ABOVE the input bar:
    // ~/Repository/asm/social (dev) 0.0%/1.0M (auto)           (merge-gateway) deepseek/deepseek-v4.1-flash • high
    let extStatusCache = new Map<string, string>();
    ctx.ui.setWidget("status-bar", (_tui: any, theme: any) => {
      return {
        render(width: number): string[] {
          return [renderStatusBarLine(ctx, pi, theme, width, extStatusCache)];
        },
        invalidate() {
          cachedGitStatus.time = 0;
        },
        dispose() {},
      };
    }, { placement: "aboveEditor" });

    // Footer: empty (status is now placed above editor)
    ctx.ui.setFooter((_tui: any, _theme: any, footerData: any) => {
      if (footerData?.getExtensionStatuses) {
        extStatusCache = footerData.getExtensionStatuses();
      }
      const unsub = footerData?.onBranchChange?.(() => {
        cachedGitStatus.time = 0;
        _tui.requestRender();
      });

      return {
        dispose() {
          unsub?.();
        },
        invalidate() {
          cachedGitStatus.time = 0;
        },
        render(_width: number): string[] {
          if (footerData?.getExtensionStatuses) {
            extStatusCache = footerData.getExtensionStatuses();
          }
          return [];
        },
      };
    });
  });
}
