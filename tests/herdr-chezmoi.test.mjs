import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

const dir = mkdtempSync(join(tmpdir(), "herdr-chezmoi-"));
const source = join(dir, "source");
const home = join(dir, "home");
const configFile = join(dir, "chezmoi.toml");
writeFileSync(configFile, "");
mkdirSync(join(source, "dot_config", "herdr"), { recursive: true });
mkdirSync(join(source, ".chezmoitemplates"), { recursive: true });
mkdirSync(join(home, ".config", "herdr"), { recursive: true });
cpSync(new URL("../dot_config/herdr/modify_config.toml", import.meta.url), join(source, "dot_config", "herdr", "modify_config.toml"));
cpSync(new URL("../.chezmoitemplates/herdr-config.toml.tmpl", import.meta.url), join(source, ".chezmoitemplates", "herdr-config.toml.tmpl"));
test.after(() => rmSync(dir, { recursive: true, force: true }));

function target(current, os) {
  const file = join(home, ".config", "herdr", "config.toml");
  if (current !== undefined) writeFileSync(file, current);
  else rmSync(file, { force: true });
  return execFileSync("chezmoi", ["-S", source, "-D", home, "-c", configFile, ...(os ? ["--override-data", JSON.stringify({ chezmoi: { os } })] : []), "cat", file], { encoding: "utf8", stdio: ["pipe", "pipe", "pipe"] });
}

function parse(content) {
  return JSON.parse(execFileSync("chezmoi", ["execute-template", "--with-stdin", "{{ .chezmoi.stdin | fromToml | toJson }}"], { input: content, encoding: "utf8" }));
}

test("adds Pi row to existing Claude rows without changing theme or comments", () => {
  const original = "# my choice\n[ui.sidebar.agents.rows_by_agent]\nclaude = [[\"agent\"]]\n\n[theme]\nname = \"kanagawa-lotus\"\n";
  const actual = target(original);
  assert.equal(actual, original.replace("claude =", "pi = [[\"state_icon\", \"workspace\", \"tab\"], [\"$summary\"], [\"agent\"]]\nclaude ="));
  assert.equal(parse(actual).theme.name, "kanagawa-lotus");
  const file = join(home, ".config", "herdr", "config.toml");
  const diff = execFileSync("chezmoi", ["-S", source, "-D", home, "-c", configFile, "diff", file], { encoding: "utf8" });
  assert.match(diff, /\+pi = /);
  assert.doesNotMatch(diff, /^[-+]name = /m);
  execFileSync("chezmoi", ["-S", source, "-D", home, "-c", configFile, "apply", file], { encoding: "utf8" });
  assert.equal(readFileSync(file, "utf8"), actual);
  assert.equal(target(actual), actual);
  assert.equal(execFileSync("chezmoi", ["-S", source, "-D", home, "-c", configFile, "diff", file], { encoding: "utf8" }), "");
});

test("seeds a full Herdr config on a fresh machine", () => {
  const config = parse(target());
  assert.deepEqual(config.ui.sidebar.agents.rows_by_agent.pi[1], ["$summary"]);
  assert.equal(config.theme.name, "kanagawa");
});

test("inserts after valid table headers with comments, spaces, or no final newline", () => {
  for (const header of [
    "[ui.sidebar.agents.rows_by_agent] # keep this comment\n",
    "[ui.sidebar.agents.rows_by_agent ]\n",
    "[ui.sidebar.agents.rows_by_agent]",
  ]) {
    const actual = target(header);
    assert.deepEqual(parse(actual).ui.sidebar.agents.rows_by_agent.pi[1], ["$summary"]);
    assert.ok(actual.startsWith(header.trimEnd()));
  }
});

test("unrelated pi keys and comments cannot masquerade as a sidebar row", () => {
  const original = "# $summary\n[tools]\npi = \"$summary\"\n\n[ui.sidebar.agents.rows_by_agent]\nclaude = [[\"agent\"]]\n";
  const actual = target(original);
  assert.deepEqual(parse(actual).ui.sidebar.agents.rows_by_agent.pi[1], ["$summary"]);
  assert.equal(parse(actual).tools.pi, "$summary");
});

test("keeps an existing custom Pi row that already displays the summary", () => {
  const original = "[ui.sidebar.agents.rows_by_agent]\npi = [[\"$summary\", \"agent\"]]\n\n[theme]\nname = \"kanagawa-lotus\"\n";
  assert.equal(target(original), original);
});

test("refuses to overwrite an incompatible custom Pi row or malformed TOML", () => {
  const file = join(home, ".config", "herdr", "config.toml");
  for (const [input, message] of [
    ["# $summary in a comment\n[ui.sidebar.agents.rows_by_agent]\npi = [[\"agent\"]]\n", "custom Pi sidebar row"],
    ["[theme\nname = \"broken\"\n", "fromToml"],
  ]) {
    assert.throws(() => target(input), (error) => error.stderr.toString().includes(message));
    assert.equal(readFileSync(file, "utf8"), input);
  }
});

test("seeds Windows default shell without a Unix-only plugin action", () => {
  const config = parse(target(undefined, "windows"));
  assert.equal(config.terminal.default_shell, "C:\\Program Files\\PowerShell\\7\\pwsh.exe");
  assert.equal(config.keys, undefined);
  assert.equal(config.ui.sidebar.agents.rows_by_agent.pi[1][0], "$summary");
});

test("adds an agent table when an existing config has none", () => {
  const original = "[theme]\nname = \"kanagawa-lotus\"\n";
  const actual = target(original);
  assert.equal(parse(actual).ui.sidebar.agents.rows_by_agent.pi[1][0], "$summary");
  assert.ok(actual.startsWith(original));
});
