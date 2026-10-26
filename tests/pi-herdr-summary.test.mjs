import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import summaryExtension from "../private_dot_pi/private_agent/extensions/herdr-summary.ts";

const dir = mkdtempSync(join(tmpdir(), "pi-herdr-summary-"));
const cli = join(dir, "herdr");
writeFileSync(cli, `#!/bin/sh\nprintf '%s\\n' "$@" >> "$HERDR_TEST_LOG"\n`, { mode: 0o755 });

test.after(() => rmSync(dir, { recursive: true, force: true }));

function harness(mode) {
  const handlers = new Map();
  let calls = 0;
  const log = join(dir, `${mode}.log`);
  writeFileSync(log, "");
  process.env.HERDR_ENV = "1";
  process.env.HERDR_PANE_ID = "test:p1";
  process.env.HERDR_BIN_PATH = cli;
  process.env.HERDR_TEST_LOG = log;
  process.env.PI_HERDR_SUMMARY_MODE = mode;
  const branch = [{ type: "message", message: { role: "assistant", stopReason: "stop", content: [{ type: "text", text: "The user wants short sidebar labels, with paid titles as the default." }] } }];
  const pi = { on: (event, handler) => handlers.set(event, handler), appendEntry: (customType, data) => branch.push({ type: "custom", customType, data }) };
  summaryExtension(pi);
  const ctx = {
    mode: "tui",
    sessionManager: { getBranch: () => branch },
    modelRegistry: {
      find: () => ({ id: "gpt-4o-mini" }),
      hasConfiguredAuth: () => true,
      complete: async (_model, request, options) => {
        calls++;
        assert.equal(options.maxTokens, 48);
        assert.match(request.messages[0].content[0].text, /short Pi conversation summaries/);
        return { stopReason: "stop", content: [{ type: "text", text: "Pi Conversation Summaries Configuration" }] };
      },
    },
  };
  return { handlers, ctx, log, branch, get calls() { return calls; } };
}

test("paid mode is the default and publishes a short model label", async () => {
  const h = harness("model");
  delete process.env.PI_HERDR_SUMMARY_MODE;
  await h.handlers.get("before_agent_start")({ messageType: "user", prompt: "Give me short Pi conversation summaries" }, h.ctx);
  await h.handlers.get("agent_settled")({ aborted: false }, h.ctx);
  assert.equal(h.calls, 1);
  assert.match(readFileSync(h.log, "utf8"), /--token\nsummary=Pi Conversation Summaries Configuration\n/);
});

test("prompt mode has no paid call and publishes at most five words", async () => {
  const h = harness("prompt");
  await h.handlers.get("before_agent_start")({ messageType: "user", prompt: "Give me short Pi conversation summaries in the agent sidebar" }, h.ctx);
  await h.handlers.get("agent_settled")({ aborted: false }, h.ctx);
  assert.equal(h.calls, 0);
  assert.match(readFileSync(h.log, "utf8"), /--token\nsummary=Give me short Pi conversation\n/);
});

test("prompt mode keeps the original topic across follow-ups", async () => {
  const h = harness("prompt");
  await h.handlers.get("before_agent_start")({ messageType: "user", prompt: "Give me short Pi conversation summaries" }, h.ctx);
  await h.handlers.get("agent_settled")({ aborted: false }, h.ctx);
  await h.handlers.get("before_agent_start")({ messageType: "user", prompt: "What about this follow up?" }, h.ctx);
  await h.handlers.get("agent_settled")({ aborted: false }, h.ctx);
  const lines = readFileSync(h.log, "utf8");
  assert.equal(lines.match(/summary=Give me short Pi conversation/g)?.length, 2);
});

test("model output cannot inject control characters or long titles", async () => {
  const h = harness("model");
  h.ctx.modelRegistry.complete = async () => ({ stopReason: "stop", content: [{ type: "text", text: "\u001b]0;bad\u0007 Five words are enough for this long summary" }] });
  await h.handlers.get("before_agent_start")({ messageType: "user", prompt: "Give me short Pi conversation summaries" }, h.ctx);
  await h.handlers.get("agent_settled")({ aborted: false }, h.ctx);
  assert.match(readFileSync(h.log, "utf8"), /--token\nsummary=]0;bad Five words are enough\n/);
});

test("resuming restores the branch's own short label", async () => {
  const h = harness("model");
  h.branch.push({ type: "custom", customType: "pi-summary", data: { title: "Existing Pi sidebar work" } });
  await h.handlers.get("session_start")({}, h.ctx);
  assert.match(readFileSync(h.log, "utf8"), /--token\nsummary=Existing Pi sidebar work\n/);
  assert.equal(h.calls, 0);
});

test("a failed model call never publishes raw prompt text", async () => {
  const h = harness("model");
  h.ctx.modelRegistry.complete = async () => { throw new Error("provider unavailable"); };
  await h.handlers.get("before_agent_start")({ messageType: "user", prompt: "my password is hunter2" }, h.ctx);
  await h.handlers.get("agent_settled")({ aborted: false }, h.ctx);
  assert.equal(readFileSync(h.log, "utf8"), "");
});

test("prompt mode hides credential-related prompts", async () => {
  const h = harness("prompt");
  await h.handlers.get("before_agent_start")({ messageType: "user", prompt: "my password is hunter2" }, h.ctx);
  await h.handlers.get("agent_settled")({ aborted: false }, h.ctx);
  assert.match(readFileSync(h.log, "utf8"), /--token\nsummary=Private request\n/);
});

test("off mode clears any existing title and makes no paid call", async () => {
  const h = harness("off");
  h.branch.push({ type: "custom", customType: "pi-summary", data: { title: "Old title" } });
  await h.handlers.get("session_start")({}, h.ctx);
  assert.match(readFileSync(h.log, "utf8"), /--clear-token\nsummary\n/);
  writeFileSync(h.log, "");
  await h.handlers.get("before_agent_start")({ messageType: "user", prompt: "Give me short Pi conversation summaries" }, h.ctx);
  await h.handlers.get("agent_settled")({ aborted: false }, h.ctx);
  assert.equal(readFileSync(h.log, "utf8"), "");
});
