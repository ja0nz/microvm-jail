import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { dirname, resolve } from "node:path";
import { promises as fs } from "node:fs";

type WriteInput = { path?: string } | undefined;
type BashInput = { command?: string } | undefined;

async function syncOwnership(targetPath: string): Promise<void> {
  const directory = dirname(targetPath);

  try {
    const [targetStats, dirStats] = await Promise.all([
      fs.stat(targetPath),
      fs.stat(directory),
    ]);

    if (targetStats.uid === dirStats.uid && targetStats.gid === dirStats.gid) return;

    await fs.chown(targetPath, dirStats.uid, dirStats.gid);
  } catch (error: any) {
    if (error?.code === "ENOENT") return; // File or dir missing, nothing to fix

    console.error(`[inherit-ownership] Failed to sync ownership for ${targetPath}:`, error);
  }
}

function normalizePath(rawPath: string, cwd: string): string {
  const trimmed = rawPath.startsWith("@") ? rawPath.slice(1) : rawPath;
  return resolve(cwd, trimmed);
}

function extractCreatedPathFromBash(command: string, cwd: string): string | null {
  // Match mkdir -p /some/path or mkdir /some/path
  const mkdirMatch = command.match(/^mkdir\s+(?:-p\s+)?(.+)$/);
  if (!mkdirMatch) return null;

  const rawPath = mkdirMatch[1].trim();
  // Skip if it looks like a variable or command substitution
  if (rawPath.startsWith("$") || rawPath.startsWith("`") || rawPath.startsWith("(")) {
    return null;
  }

  return normalizePath(rawPath, cwd);
}

export default function (pi: ExtensionAPI) {
  // Handle file creation via "write" tool
  pi.on("tool_result", async (event, ctx) => {
    if (event.toolName !== "write" || event.isError) return;

    const pathArg = (event.input as WriteInput)?.path;
    if (!pathArg) return;

    const absolutePath = normalizePath(pathArg, ctx.cwd);
    await syncOwnership(absolutePath);
  });

  // Handle folder creation via "bash" tool (mkdir)
  pi.on("tool_result", async (event, ctx) => {
    if (event.toolName !== "bash" || event.isError) return;

    const command = (event.input as BashInput)?.command;
    if (!command) return;

    const absolutePath = extractCreatedPathFromBash(command, ctx.cwd);
    if (!absolutePath) return;

    await syncOwnership(absolutePath);
  });
}