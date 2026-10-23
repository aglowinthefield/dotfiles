/**
 * Jev router: `jev/auto`, a virtual model that plans on a strong model and implements on a cheaper one.
 *
 * - Planning: Opus for complex work, Sonnet otherwise. Jev rates the first user message of the session.
 * - Implementation: after the first successful `edit` or `write`, the session moves to Sonnet for good.
 *   A session that planned on Sonnet never switches, so it never pays the cache miss.
 *
 * Fallback: when a request fails on a rate or usage limit, the session moves to the next account in
 * FALLBACK (anthropic, then the second Anthropic login, then OpenAI) and stays there. multi-pass has
 * no pools or chains configured and does not see virtual models, so the router does this itself.
 *
 * Adapted from Pi's examples/extensions/jev-router.ts, which routes between OpenAI Codex models.
 */

import type { Message } from "@earendil-works/pi-ai";
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
];

/** Tools whose successful result means implementation has started. */
const EDIT_TOOLS = new Set(["edit", "write"]);

/** Error text that means the account is out of quota rather than broken. */
const LIMIT_ERROR = /rate.?limit|usage.?limit|quota|429|too many requests|overloaded|529/i;

interface JevState {
	phase: "planning" | "implementation";
	role: Role;
	/** Index into FALLBACK. */
	account: number;
}

type JevRequest = ModelRouteRequest<JevState>;

function routeTo(request: JevRequest, ctx: ExtensionContext, state: JevState, save: boolean): ModelRoute<JevState> {
	const { provider, models } = FALLBACK[state.account];
	const model = ctx.modelRegistry.find(provider, models[state.role]);
	if (!model) throw new Error(`Model ${provider}/${models[state.role]} is not in the catalog`);
	return { model, thinkingLevel: request.thinkingLevel, state: save ? state : undefined };
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

/** Next account after `from` that has credentials and the model for `role`. */
function nextAccount(ctx: ExtensionContext, from: number, role: Role): number | undefined {
	for (let i = from + 1; i < FALLBACK.length; i++) {
		const { provider, models } = FALLBACK[i];
		const model = ctx.modelRegistry.find(provider, models[role]);
		if (model && ctx.modelRegistry.hasConfiguredAuth(model)) return i;
	}
	return undefined;
}

/** Planning role for a new session: complex for hard work, standard otherwise or when Jev is unavailable. */
async function choosePlanningRole(request: JevRequest, ctx: ExtensionContext): Promise<Role> {
	const jev = ctx.modelRegistry.findOfType("classifier", "typesafe", "jev-latest");
	if (!jev) return "standard";
	const result = await ctx.modelRegistry.classify(
		jev,
		{
			state: { prompt: lastUserText(request.messages).slice(0, 16_000) },
			questions: {
				complexity: {
					type: "choice",
					instructions: "How demanding is the software engineering work requested in `prompt`?",
					criteria: {
						standard: "Ordinary features, fixes, reviews, or questions",
						complex: "Subtle design, cross-cutting changes, or hard debugging",
					},
				},
			},
		},
		{ signal: request.signal },
	);
	const answer = result.stopReason === "stop" ? result.answers.complexity : undefined;
	return answer?.type === "choice" && (answer.probabilities.complex ?? 0) >= 0.5 ? "complex" : "standard";
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
				state = { phase: "planning", role: await choosePlanningRole(request, ctx), account: 0 };
				changed = true;
			}

			// The planning model made the first edit: hand the rest of the work to the implementation model.
			if (state.phase === "planning" && editedThisTurn(request.messages)) {
				state = { ...state, phase: "implementation", role: "implementation" };
				changed = true;
			}

			// Out of quota on this account: move to the next one for the rest of the session.
			if (limitError(request)) {
				const next = nextAccount(ctx, state.account, state.role);
				if (next !== undefined) {
					state = { ...state, account: next };
					changed = true;
				}
			}

			return routeTo(request, ctx, state, changed);
		},
	});
}
