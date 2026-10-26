// PI_HERDR_SUMMARY_MODE=model (default), prompt (no API call), or off.
// PI_HERDR_SUMMARY_MODEL overrides openrouter/openai/gpt-4o-mini.
// The model sees at most 600 characters each of the prompt and assistant reply.
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const run = promisify(execFile);
const source = "pi-summary";
const promptMode = new Set(["model", "prompt", "off"]);
const systemPrompt = "Name the current coding conversation for a narrow sidebar. Return only a specific 2-5 word title. No punctuation, quotes, or generic words like conversation or configuration unless they are the topic. Use the latest user request and assistant result to track topic changes. Never include credentials.";

function label(text: string): string {
  // Never expose a prompt fragment or model output that looks like a credential.
  if (/\b(password|secret|credential|api[_ -]?key|token)\b|sk-[a-z0-9_-]{8}/i.test(text)) return "Private request";
  const words = text.replace(/[\x00-\x1f\x7f-\x9f]/g, " ").replace(/["'`]/g, "").trim().split(/\s+/).slice(0, 5);
  if (words.some((word) => /[a-z0-9_-]{16,}/i.test(word))) return "Private request";
  return words.join(" ").slice(0, 40).trim();
}

function currentPane(ctx: ExtensionContext): string | undefined {
  return ctx.mode === "tui" && process.env.HERDR_ENV === "1" ? process.env.HERDR_PANE_ID : undefined;
}

async function publish(ctx: ExtensionContext, title?: string): Promise<void> {
  const pane = currentPane(ctx);
  if (!pane) return;
  const args = ["pane", "report-metadata", pane, "--source", source, "--agent", "pi"];
  if (title) args.push("--token", `summary=${title}`);
  else args.push("--clear-token", "summary");
  try {
    await run(process.env.HERDR_BIN_PATH || "herdr", args, { timeout: 2000 });
  } catch (error) {
    console.error(`pi-herdr-summary: ${String(error)}`);
  }
}

function latestAnswer(ctx: ExtensionContext): string {
  for (const entry of ctx.sessionManager.getBranch().toReversed()) {
    if (entry.type !== "message" || entry.message.role !== "assistant" || entry.message.stopReason !== "stop") continue;
    return entry.message.content.filter((part) => part.type === "text").map((part) => part.text).join(" ").slice(0, 600);
  }
  return "";
}

export default function (pi: ExtensionAPI) {
  let prompt = "";
  let prior = "";

  pi.on("session_start", async (_event, ctx) => {
    prompt = "";
    const saved = ctx.sessionManager.getBranch().toReversed().find((entry) => entry.type === "custom" && entry.customType === source);
    prior = saved?.type === "custom" && typeof (saved.data as { title?: unknown } | undefined)?.title === "string"
      ? label((saved.data as { title: string }).title) : "";
    await publish(ctx, process.env.PI_HERDR_SUMMARY_MODE === "off" ? undefined : prior); // Do not inherit another session's label.
  });

  pi.on("before_agent_start", (event, ctx) => {
    if (event.messageType !== "user" || !currentPane(ctx)) return;
    prompt = event.prompt.slice(0, 600);
  });

  pi.on("agent_settled", async (event, ctx) => {
    if (event.aborted || !prompt || !currentPane(ctx)) return;
    const mode = process.env.PI_HERDR_SUMMARY_MODE || "model";
    if (!promptMode.has(mode) || mode === "off") return;
    const currentPrompt = prompt;
    prompt = "";
    let title = mode === "prompt" ? prior || label(currentPrompt) : prior;
    if (mode === "model") {
      const modelName = process.env.PI_HERDR_SUMMARY_MODEL || "openrouter/openai/gpt-4o-mini";
      const slash = modelName.indexOf("/");
      const model = ctx.modelRegistry.find(modelName.slice(0, slash), modelName.slice(slash + 1));
      if (model && ctx.modelRegistry.hasConfiguredAuth(model)) {
        try {
          const response = await ctx.modelRegistry.complete(model, {
            systemPrompt,
            messages: [{ role: "user", content: [{ type: "text", text: `Previous title: ${prior}\nUser: ${currentPrompt}\nAssistant: ${latestAnswer(ctx)}` }], timestamp: Date.now() }],
          }, { maxTokens: 48 });
          if (response.stopReason === "stop") title = label(response.content.filter((part) => part.type === "text").map((part) => part.text).join(" ")) || title;
        } catch (error) {
          console.error(`pi-herdr-summary: model call failed: ${String(error)}`);
        }
      } else {
        console.error(`pi-herdr-summary: model unavailable: ${modelName}; keeping previous title`);
      }
    }
    if (!title) return;
    prior = title;
    pi.appendEntry(source, { title });
    await publish(ctx, title);
  });
}
