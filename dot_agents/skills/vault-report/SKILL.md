---
name: vault-report
description: Save a Tailwind + Mermaid HTML report into the Obsidian vault as notes that keep its layout and follow the vault theme, one note per section plus an index. Use when a skill or task produces an HTML report (architecture reviews, audits, explainers, comparisons), when the user asks to put a report in Obsidian or the vault, or to refresh report notes after the theme or palette changes.
---

# Vault report

`scripts/vault-report.mjs` turns an HTML report into vault notes. Each `data-note` section becomes a note, everything else becomes the index note. Mermaid diagrams are rendered to static SVG, every colour is mapped by role onto the theme (Compline's `--c-*` variables, with Obsidian's own as the fallback), and one shared snippet, `.obsidian/snippets/vault-report.css`, is rebuilt from every report note in the vault and enabled.

## Write the report for it

- Style with stock Tailwind classes, the default palette, and design it light: white cards on a stone page, slate text. Colour by meaning, because each family becomes a theme colour: red for problems, emerald for what's good or deep, amber for caution, sky or blue for links, neutrals for structure. A `bg-slate-900` slab becomes a raised dark slab. A custom `tailwind.config` is dropped.
- Put the content in `<main>`. Mark each element that should be its own note with `data-note="<note name>"`, and give it its own heading, since the note's inline title is hidden. `data-props='{"strength":"Strong"}'` adds frontmatter to that note; on `<main>` it adds frontmatter to the index. `data-note-skip` drops a wrapper (an emptied card grid) from the index.
- Link between sections with `href="#id"`. Links become internal links to the note that holds the target.
- Diagrams go in `<pre class="mermaid">`. Classic `classDef` colours from the Tailwind palette map like everything else.
- The report's own `<style>` is kept, scoped to this report and themed.
- Notes are static. Obsidian runs no scripts, so anything built or toggled by JS at view time is lost. Images need absolute URLs or data URIs.

## Run it

```bash
node ~/.agents/skills/vault-report/scripts/vault-report.mjs <report.html> \
  --dest "<folder inside the vault>" --name "<index note name>" [--date YYYY-MM-DD]
```

- The vault is `$DEV_VAULT` (else `~/Documents/Dev`); `--vault` overrides. Put the folder where the global "Written reports" rule says, such as `Silk/<topic>/`. Notes get `status: needs-review`, `date`, and a `report:` link to the index; `--status` changes the first.
- It refuses to overwrite existing notes. Check them for the user's annotations first (`rg -n '%%|\{>>' <folder>`); if there are none, rerun with `--force`. Notes in the folder that this export didn't write are listed, never deleted.
- `--rebuild` regenerates the snippet only: after deleting a report folder, or after changing the colour roles in `scripts/palette.mjs`.
- Needs Chrome (Playwright's cached Chromium, or `$CHROME`) and network for Mermaid. The first run installs Tailwind 3 and PostCSS into `~/.cache/vault-report`.
- A render error (bad Mermaid, duplicate note names) stops the export before anything is written.

Tell the user the index note's path when done.

## Checking the result

Obsidian reloads the snippet itself. To look without screenshots, open the note with `/Applications/Obsidian.app/Contents/MacOS/obsidian-cli open vault=<name> path="<folder>/<note>.md"`. When the Obsidian window is hidden its reading view never renders, so an `eval` against the active leaf finds nothing. Render into a detached element instead: walk the prototype chain of `app.workspace.activeLeaf.view.previewMode` to the constructor that has a static `render`, call `render(app, markdown, el, path, view)` on an element inside a `.markdown-preview-view.markdown-rendered.vault-report` wrapper, and read computed styles from `.vr-page`. The CLI exits 0 even on errors, so read its output.

## Why it works the way it does

- Obsidian strips `<style>` and `<foreignObject>` inside SVG, so Mermaid renders with SVG text labels and every computed style is inlined.
- A blank line ends an HTML block and indented lines after it read as code, so notes go out with no blank lines and no indentation; `<pre>` keeps its newlines as entities.
- Theme and snippet rules on `h1`, `code`, `table`, `td` and `li` outrank plain utilities, so preflight and utilities are `!important` under `.vault-report .vr-page`, and a reset block covers what Obsidian styles more specifically.
- A pane is narrower than the window, so viewport breakpoints become container queries; Obsidian's root font size is its text size, so `rem` becomes `px`.
