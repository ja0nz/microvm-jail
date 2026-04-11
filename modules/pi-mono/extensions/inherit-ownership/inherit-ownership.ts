import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { dirname, resolve } from "node:path";
import { promises as fs } from "node:fs";

type WriteInput = { path?: string } | undefined;

async function syncOwnership(targetPath: string): Promise<void> {
  const directory = dirname(targetPath);

  try {
    const [fileStats, dirStats] = await Promise.all([
      fs.stat(targetPath),
      fs.stat(directory),
    ]);

    if (fileStats.uid === dirStats.uid && fileStats.gid === dirStats.gid) return;

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

export default function (pi: ExtensionAPI) {
  pi.on("tool_result", async (event, ctx) => {
    if (event.toolName !== "write" || event.isError) return;

    const pathArg = (event.input as WriteInput)?.path;
    if (!pathArg) return;

    const absolutePath = normalizePath(pathArg, ctx.cwd);
    await syncOwnership(absolutePath);
  });
}
