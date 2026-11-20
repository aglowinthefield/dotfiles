/**
 * Personalities, ported from Hermes Agent's `display.personality`.
 *
 * Each `~/.pi/agent/personalities/<name>.md` is a personality; its text goes into the
 * system prompt as a `<personality>` section. `personalities/default` names the one every
 * session starts with. `/personality` lists them, `/personality <name>` switches this
 * session, `/personality off` drops it.
 */

import { existsSync, readdirSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const DIR = join(homedir(), ".pi", "agent", "personalities");

function names(): string[] {
	if (!existsSync(DIR)) return [];
	return readdirSync(DIR)
		.filter((f) => f.endsWith(".md"))
		.map((f) => f.slice(0, -3))
		.sort();
}

function load(name: string): string | undefined {
	const file = join(DIR, `${name}.md`);
	return existsSync(file) ? readFileSync(file, "utf8").trim() : undefined;
}

function defaultName(): string | undefined {
	const file = join(DIR, "default");
	if (!existsSync(file)) return undefined;
	const name = readFileSync(file, "utf8").trim();
	return name && name !== "off" ? name : undefined;
}

export default function personality(pi: ExtensionAPI) {
	let current = defaultName();

	pi.registerCommand("personality", {
		description: "List personalities, switch to one, or turn it off",
		handler: async (args, ctx) => {
			const want = args.trim();
			if (!want) {
				const list = names()
					.map((n) => (n === current ? `${n} (active)` : n))
					.join(", ");
				ctx.ui.notify(`Personalities: ${list || "none"}. Use /personality <name> or off.`, "info");
				return;
			}
			if (want === "off" || want === "none") {
				current = undefined;
				ctx.ui.notify("Personality off", "info");
				return;
			}
			if (!load(want)) {
				ctx.ui.notify(`No personality "${want}" in ${DIR}`, "error");
				return;
			}
			current = want;
			ctx.ui.notify(`Personality: ${want}`, "info");
		},
	});

	pi.on("before_agent_start", async (event) => {
		const sections = event.systemPromptOptions.sections ?? {};
		const text = current ? load(current) : undefined;
		if (text) sections.personality = text;
		else delete sections.personality;
		event.systemPromptOptions.sections = sections;
		return undefined;
	});
}
