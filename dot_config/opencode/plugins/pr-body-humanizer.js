// Run ClearStack's pr-body-guard on gh commands that post a PR body or comment.
import { spawnSync } from 'node:child_process';
import { homedir } from 'node:os';
import { join } from 'node:path';

// Call Python directly; Windows uses its standard executable name.
const SCRIPT = join(homedir(), '.agents', 'skills', 'clear-voice', 'scripts', 'pr-body-guard');
const PYTHON = process.platform === 'win32' ? 'python' : 'python3';

export const PrBodyHumanizer = async () => ({
  'tool.execute.before': async (input, output) => {
    if (input.tool !== 'bash') return;
    const command = output?.args?.command;
    if (typeof command !== 'string' || !command.includes('gh')) return;

    const res = spawnSync(PYTHON, [SCRIPT], {
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

    let reason = 'Blocked by pr-body-guard';
    try {
      reason = JSON.parse(res.stdout).reason || reason;
    } catch {
      if (res.stderr?.trim()) reason = res.stderr.trim();
    }
    throw new Error(reason);
  },
});
