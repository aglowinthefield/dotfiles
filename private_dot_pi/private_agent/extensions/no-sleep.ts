// Blocks fixed `sleep N` waits in bash, including bash calls made from codemode.
// A sleep inside an until/while loop is allowed, since that polls a real condition.
// The block reason goes back to the agent so it picks a real wait instead.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const BARE_SLEEP = /(^|[;&|(]\s*|\n\s*)sleep\s+\d/;
const LOOP = /\b(until|while)\b/;

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", (event) => {
    if (event.toolName.toLowerCase() !== "bash") return;
    const cmd = String((event.input as { command?: unknown })?.command ?? "");
    if (!BARE_SLEEP.test(cmd) || LOOP.test(cmd)) return;
    return {
      block: true,
      reason:
        "Fixed sleeps are blocked. Wait on the real condition instead: a blocking command " +
        "(gh run watch, gh pr checks --watch, flyctl --wait, acp_delegate_wait) or " +
        "`timeout 300 sh -c 'until <check>; do sleep 2; done'`.",
    };
  });
}
