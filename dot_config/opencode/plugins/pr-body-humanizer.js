// Validate PR descriptions only; shared dispatcher skips reads, comments and other commands.
import { spawnSync } from 'node:child_process';
import { homedir } from 'node:os';
import { join } from 'node:path';

// Call the Python dispatcher directly: Windows has python3 (scoop) but no sh.
const SCRIPT = join(homedir(), '.agents', 'hooks', 'dispatch-pr-body.py');

export const PrBodyHumanizer = async () => ({
  'tool.execute.before': async (input, output) => {
    if (input.tool !== 'bash') return;
    const command = output?.args?.command;
    if (typeof command !== 'string' || !command.includes('gh')) return;

    const res = spawnSync('python3', [SCRIPT], {
      input: JSON.stringify({
        cwd: output?.args?.workdir || process.cwd(),
        hook_event_name: 'pre_tool_call',
        tool_name: 'bash',
        tool_input: { command },
      }),
      encoding: 'utf8',
      timeout: 10_000,
    });
    if (res.status !== 2) return; // 0 = allow; anything else = fail open

    let reason = 'Blocked by the PR body humanizer';
    try {
      reason = JSON.parse(res.stdout).reason || reason;
    } catch {
      if (res.stderr?.trim()) reason = res.stderr.trim();
    }
    throw new Error(reason);
  },
});
