---
name: share-preview
description: Host a local HTML page or dashboard so other people can open it and change it together live, over ngrok with a password (or LAN only). Use when the user wants to share a preview, picker, review board or dashboard with someone else, says "host this for X", "can someone else try this", "ngrok this", or wants two people choosing things in the same page at once.
---

# Share preview

`scripts/share.sh` serves a directory with `scripts/server.mjs` and opens an ngrok tunnel with basic auth. The server adds a small shared key/value store: when one person changes something, every open page gets the new state at once.

## Build the page for it

- Put the page in its own directory as `index.html`, with its data baked in. Keep build scripts and secrets (database URLs) out of that directory or in `.share/`, which the server never serves.
- Load `<script src="/_shared/client.js"></script>` and keep every shared choice in `Shared`:
  - `Shared.on(state => render())` runs on load and on every change. `state[key]` is `{ value, by, at }`.
  - `Shared.set(key, value)` saves for everyone; `null` deletes. Key by stable ids (`pick:<packId>`), and store values that survive a data rebuild (an image name or row id, not an array index).
  - `Shared.name` is the person's name, asked once per browser. Show `by` next to changed items so people see who changed what.
- Keep view-only settings (filters, sort, scroll) local. Sharing them makes people fight over the view.
- On `file://` the page still works, but changes stay local.
- If people pick between options, end with an output that applies the result (SQL, JSON, a command) that someone can copy.

## Run it

```bash
S=~/.agents/skills/share-preview/scripts/share.sh
$S start <dir> [port]   # server + ngrok; prints the public URL, user and password
$S lan <dir> [port]     # LAN only, no tunnel
$S status <dir>
$S stop <dir>           # stop server and tunnel; state stays in <dir>/.share/state.json
```

The default port is 4321. Rebuilding `index.html` while it runs is fine. The server reads files on each request, so people reload to see the new data, and the shared state carries over.

## Things that bit before

- LAN sharing often fails on office Wi-Fi, which blocks connections between devices. Go straight to `start` (ngrok) unless the user wants LAN only.
- The ngrok URL is public, behind basic auth (user `share`, random password in `.share/password`). Free ngrok shows a "you are about to visit" page first; people click through. Tell the user what data the page shows before they send the link: prod usernames, prod-fork rows and similar should go only to people who may see them.
- A restart gets a new ngrok URL. Reuse the running tunnel when you can.
- Prod data for the page comes from a read-only prod fork (in Silk: `npm run --silent neon:prod-fork-ro -- --name <purpose>`). Keep its URL in a mode-600 file outside the served directory.

## Tear down

1. Read `<dir>/.share/state.json` first. It holds what the other people chose, and it is often the whole point of the session. Turn it into its output (SQL, a list) and save that in the vault before anything else.
2. `$S stop <dir>`, then delete the directory.
3. Leave tunnels you did not start alone; other sessions run their own ngrok.

A prod fork expires on its own.
