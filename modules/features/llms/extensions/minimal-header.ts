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
try {
  CustomEditorBase = require("@earendil-works/pi-coding-agent").CustomEditor;
} catch {
  try {
    CustomEditorBase = require("/nix/store/m58mjsdjgk3zrwar1ckw2lb4q241l7j9-pi-coding-agent-0.85.1/lib/node_modules/pi-monorepo/dist/index.js").CustomEditor;
  } catch {}
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

export default function (pi: any) {
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
