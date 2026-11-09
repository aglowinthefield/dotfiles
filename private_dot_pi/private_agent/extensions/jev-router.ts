/**
 * Jev router: `jev/auto`, a virtual model that plans on a strong model and implements on a cheaper one.
 *
 * - Planning: Opus for complex work, GPT-6.1 Sol on low thinking otherwise. Jev rates the first user
 *   message of the session. Prompts with almost no text (a bare URL, a few words) skip Jev and go standard,
 *   because Jev over-rated them as complex.
 * - Implementation: after the first successful `edit` or `write`, a session that planned on Opus moves to
 *   Sonnet for good. A standard session never switches, so it never pays the cache miss.
 * - Escalation: a standard session that runs past ESCALATE_ASSISTANT_TURNS assistant turns or
 *   ESCALATE_USER_MESSAGES user messages moves to Opus once.
 *
 * Fallback: when a request fails on a rate or usage limit, the session moves to the next account in the
 * role's chain (CHAINS) and stays there. multi-pass does not see virtual models, so its chains never
 * apply here and the router does this itself.
 *
 * Adapted from Pi's examples/extensions/jev-router.ts, which routes between OpenAI Codex models.
 */

import { appendFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { Message } from "@earendil-works/pi-ai";
import type { ThinkingLevel } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext, ModelRoute, ModelRouteRequest } from "@earendil-works/pi-coding-agent";

type Role = "complex" | "standard" | "implementation";

/** Accounts in fallback order, with the model each one uses for each role. */
const FALLBACK: readonly { provider: string; models: Record<Role, string> }[] = [
	{
		provider: "anthropic",
		models: { complex: "claude-opus-5-5", standard: "claude-sonnet-5-5", implementation: "claude-sonnet-5-5" },
	},
	{
		provider: "anthropic-2",
		models: { complex: "claude-opus-5-5", standard: "claude-sonnet-5-5", implementation: "claude-sonnet-5-5" },
	},
	{
		// GPT-6 has no Terra tier, so standard planning stays on Sol.
		provider: "openai",
		models: { complex: "gpt-6.1-sol", standard: "gpt-6.1-sol", implementation: "gpt-6-luna" },
	},
	{
		// Kimi platform API key (platform.kimi.ai, `/login moonshotai`). Skipped until a key exists.
		provider: "moonshotai",
		models: { complex: "kimi-k3.1-pro", standard: "kimi-k3.1-pro", implementation: "kimi-k2.7-code" },
	},
];

/** Account order per role, as indexes into FALLBACK. Standard work prefers OpenAI, complex work Anthropic. */
const CHAINS: Record<Role, readonly number[]> = {
	complex: [0, 1, 2, 3],
	standard: [2, 0, 1, 3],
	implementation: [0, 1, 2, 3],
};

/** Thinking level forced for the account and role, when Pi's selected level should not apply. */
function thinkingFor(provider: string, role: Role, requested: ThinkingLevel): ThinkingLevel {
	return provider === "openai" && role === "standard" ? "low" : requested;
}

/** Prompts with fewer characters than this, after removing URLs, skip Jev and plan as standard. */
const LOW_INFO_CHARS = 40;

/** A standard session past either of these moves to Opus once. */
const ESCALATE_ASSISTANT_TURNS = 60;
const ESCALATE_USER_MESSAGES = 10;

/**
 * Probability of `complex` at which planning goes to Opus. Kept below 0.5 because at 0.5 Jev sent
 * 37 of 38 sessions (Oct 28–29, 2026) to Sonnet.
 */
const COMPLEX_THRESHOLD = 0.35;

/** Tools whose successful result means implementation has started. */
const EDIT_TOOLS = new Set(["edit", "write"]);

/** Error text that means the account is out of quota rather than broken. */
const LIMIT_ERROR = /rate.?limit|usage.?limit|quota|429|too many requests|overloaded|529/i;

/** One JSON line per routing decision (not per turn), for judging the router later. */
const LOG_FILE = join(homedir(), ".pi", "agent", "jev-router.log.jsonl");

function logDecision(ctx: ExtensionContext, event: string, fields: Record<string, unknown>): void {
	try {
		const line = { ts: new Date().toISOString(), session: ctx.sessionManager?.getSessionId?.(), event, ...fields };
		appendFileSync(LOG_FILE, `${JSON.stringify(line)}\n`);
	} catch {
		// Logging must never break routing.
	}
}

interface JevState {
	phase: "planning" | "implementation";
	role: Role;
	/** Position in CHAINS[role]. */
	account: number;
	/** Set once the session has escalated, so it only happens once. */
	escalated?: boolean;
}

type JevRequest = ModelRouteRequest<JevState>;

function routeTo(request: JevRequest, ctx: ExtensionContext, state: JevState, save: boolean): ModelRoute<JevState> {
	const { provider, models } = FALLBACK[CHAINS[state.role][state.account]];
	const model = ctx.modelRegistry.find(provider, models[state.role]);
	if (!model) throw new Error(`Model ${provider}/${models[state.role]} is not in the catalog`);
	return { model, thinkingLevel: thinkingFor(provider, state.role, request.thinkingLevel), state: save ? state : undefined };
}

function lastUserText(messages: readonly Message[]): string {
	const content = messages.filter((message) => message.role === "user").at(-1)?.content ?? "";
	if (typeof content === "string") return content;
	return content.flatMap((block) => (block.type === "text" ? [block.text] : [])).join("\n");
}

/** Whether a tool call since the last user message edited a file successfully. */
function editedThisTurn(messages: readonly Message[]): boolean {
	const lastUser = messages.findLastIndex((message) => message.role === "user");
	return messages
		.slice(lastUser + 1)
		.some((message) => message.role === "toolResult" && EDIT_TOOLS.has(message.toolName) && !message.isError);
}

/**
 * The limit error that ended the last attempt, if any: a retry's failed message, or, when Pi gave up
 * and the user sent a new message, the last assistant message before it.
 */
function limitError(request: JevRequest): string | undefined {
	const failed = request.failed?.message;
	if (failed?.errorMessage && LIMIT_ERROR.test(failed.errorMessage)) return failed.errorMessage;
	if (request.reason !== "user") return undefined;
	const last = request.messages.findLast((message) => message.role === "assistant");
	if (last?.role === "assistant" && last.stopReason === "error" && LIMIT_ERROR.test(last.errorMessage ?? "")) {
		return last.errorMessage;
	}
	return undefined;
}

/** Next chain position after `from` that has credentials and the model for `role`. */
function nextAccount(ctx: ExtensionContext, from: number, role: Role): number | undefined {
	const chain = CHAINS[role];
	for (let i = from + 1; i < chain.length; i++) {
		const { provider, models } = FALLBACK[chain[i]];
		const model = ctx.modelRegistry.find(provider, models[role]);
		if (model && ctx.modelRegistry.hasConfiguredAuth(model)) return i;
	}
	return undefined;
}

/** Planning role for a new session: complex for hard work, standard otherwise or when Jev is unavailable. */
async function choosePlanningRole(
	request: JevRequest,
	ctx: ExtensionContext,
): Promise<{ role: Role; probability?: number; lowInfo?: boolean }> {
	const prompt = lastUserText(request.messages);
	if (prompt.replace(/https?:\/\/\S+/g, "").trim().length < LOW_INFO_CHARS) return { role: "standard", lowInfo: true };
	const jev = ctx.modelRegistry.findOfType("classifier", "typesafe", "jev-latest");
	if (!jev) return { role: "standard" };
	const result = await ctx.modelRegistry.classify(
		jev,
		{
			state: { prompt: lastUserText(request.messages).slice(0, 16_000) },
			questions: {
				complexity: {
					type: "choice",
					instructions: "How demanding is the software engineering work requested in `prompt`?",
					criteria: {
						standard: "Small, well-specified changes, quick fixes, or simple questions",
						complex: "Work that needs a plan: multi-file features, design choices, refactors, or debugging an unclear cause",
					},
				},
			},
		},
		{ signal: request.signal },
	);
	const answer = result.stopReason === "stop" ? result.answers.complexity : undefined;
	const probability = answer?.type === "choice" ? (answer.probabilities.complex ?? 0) : undefined;
	return { role: probability !== undefined && probability >= COMPLEX_THRESHOLD ? "complex" : "standard", probability };
}

export default function (pi: ExtensionAPI) {
	pi.registerVirtualModel<JevState>({
		provider: "jev",
		id: "auto",
		name: "Auto (Jev)",
		thinkingLevels: ["low", "medium", "high", "xhigh"],
		// Claude limits; the OpenAI fallback has 272K, and Pi compacts before routing there if needed.
		contextWindow: 1_000_000,
		maxTokens: 128_000,
		async route(request, ctx) {
			// Compaction summaries and other direct calls: implementation model on the session's account.
			if (request.reason === "direct") {
				return routeTo(request, ctx, { phase: "implementation", role: "implementation", account: 0 }, false);
			}

			let state = request.state;
			let changed = false;
			if (!state) {
				const { role, probability, lowInfo } = await choosePlanningRole(request, ctx);
				state = { phase: "planning", role, account: 0 };
				changed = true;
				logDecision(ctx, "plan", {
					role,
					pComplex: probability,
					lowInfo,
					threshold: COMPLEX_THRESHOLD,
					promptChars: lastUserText(request.messages).length,
					prompt: lastUserText(request.messages).slice(0, 300),
				});
			}

			// The planning model made the first edit: hand the rest of the work to the implementation model.
			if (state.phase === "planning" && state.role === "complex" && editedThisTurn(request.messages)) {
				state = { ...state, phase: "implementation", role: "implementation" };
				changed = true;
				logDecision(ctx, "implement", { from: request.state?.role ?? state.role });
			}

			// A standard session that keeps going is harder than it looked: move it to Opus once.
			if (state.role === "standard" && !state.escalated) {
				const assistantTurns = request.messages.filter((message) => message.role === "assistant").length;
				const userMessages = request.messages.filter((message) => message.role === "user").length;
				if (assistantTurns >= ESCALATE_ASSISTANT_TURNS || userMessages >= ESCALATE_USER_MESSAGES) {
					state = { phase: "planning", role: "complex", account: 0, escalated: true };
					changed = true;
					logDecision(ctx, "escalate", { assistantTurns, userMessages });
				}
			}

			// Out of quota on this account: move to the next one for the rest of the session.
			if (limitError(request)) {
				const next = nextAccount(ctx, state.account, state.role);
				if (next !== undefined) {
					logDecision(ctx, "fallback", { from: FALLBACK[CHAINS[state.role][state.account]].provider, to: FALLBACK[CHAINS[state.role][next]].provider });
					state = { ...state, account: next };
					changed = true;
				}
			}

			return routeTo(request, ctx, state, changed);
		},
	});
}
