#!/usr/bin/env node
// Turn a Tailwind + Mermaid HTML report into Obsidian notes that keep its layout and follow
// the vault's theme. See ../SKILL.md for the report conventions.
//
//   node vault-report.mjs <report.html> --dest "<vault folder>" [--name "<index note>"]
//        [--date YYYY-MM-DD] [--status needs-review] [--vault <path>] [--force]
//   node vault-report.mjs --rebuild [--vault <path>]
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { homedir, tmpdir } from 'node:os';
import { basename, dirname, join, relative, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { C, SENTINELS, kindForProp, setPalette, tailwindTheme, themeValue } from './palette.mjs';

const DEPS = join(homedir(), '.cache/vault-report');
const SNIPPET = 'vault-report';
const CLASS = 'vault-report';

// ---------- args ----------
const argv = process.argv.slice(2);
const opts = { positional: [] };
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--rebuild' || a === '--force') opts[a.slice(2)] = true;
  else if (a.startsWith('--')) opts[a.slice(2)] = argv[++i];
  else opts.positional.push(a);
}
const VAULT = resolve(opts.vault || process.env.DEV_VAULT || join(homedir(), 'Documents/Dev'));
if (!existsSync(join(VAULT, '.obsidian'))) die(`not an Obsidian vault: ${VAULT}`);

function die(msg) {
  console.error(`vault-report: ${msg}`);
  process.exit(1);
}

// ---------- deps: Tailwind v3 (the major the CDN build serves) + PostCSS, outside any repo ----------
function deps() {
  const req = createRequire(join(DEPS, 'package.json'));
  try {
    req.resolve('tailwindcss');
    req.resolve('postcss');
  } catch {
    mkdirSync(DEPS, { recursive: true });
    if (!existsSync(join(DEPS, 'package.json'))) writeFileSync(join(DEPS, 'package.json'), '{"private":true}\n');
    console.log(`installing tailwindcss@3 + postcss into ${DEPS}`);
    execFileSync('npm', ['i', '--silent', '--no-audit', '--no-fund', 'tailwindcss@3.4.19', 'postcss@8'], { cwd: DEPS, stdio: 'inherit' });
  }
  return { postcss: req('postcss'), tailwind: req('tailwindcss'), colors: req('tailwindcss/colors') };
}

// ---------- shared helpers ----------
export const noteName = s =>
  s.replace(/\s*:\s*/g, ' - ').replace(/[\\/#^|[\]]/g, '-').replace(/[*"<>?]/g, '').replace(/\s+/g, ' ').trim();
const slug = s => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const yamlScalar = v =>
  typeof v !== 'string' ? String(v) : /^[A-Za-z0-9][\w-]*$/.test(v) && !/^(true|false|null|yes|no|on|off)$/i.test(v) ? v : JSON.stringify(v);
const yamlFields = obj =>
  Object.entries(obj).flatMap(([k, v]) =>
    v == null ? [] : Array.isArray(v) ? [`${k}:`, ...v.map(x => `  - ${yamlScalar(x)}`)] : [`${k}: ${yamlScalar(v)}`]
  );
const frontmatter = obj => ['---', ...yamlFields(obj), 'cssclasses:', '  - wide', `  - ${CLASS}`, '---', ''].join('\n');

function chrome() {
  if (process.env.CHROME) return process.env.CHROME;
  const pw = join(homedir(), 'Library/Caches/ms-playwright');
  if (existsSync(pw)) {
    for (const d of readdirSync(pw).filter(d => /^chromium-\d+$/.test(d)).sort().reverse()) {
      const base = join(pw, d, 'chrome-mac-arm64');
      if (!existsSync(base)) continue;
      const app = readdirSync(base).find(f => f.endsWith('.app'));
      if (!app) continue;
      const bin = readdirSync(join(base, app, 'Contents/MacOS'))[0];
      if (bin) return join(base, app, 'Contents/MacOS', bin);
    }
  }
  for (const p of ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/Applications/Chromium.app/Contents/MacOS/Chromium'])
    if (existsSync(p)) return p;
  die('no Chrome found; set $CHROME');
}

// ---------- step 1: render diagrams and split the report, inside Chrome ----------
// Obsidian strips <style> and <foreignObject> inside SVG, so Mermaid renders with SVG text
// labels and every computed style is inlined. The split happens in the page too, so no HTML
// parser is needed here.
function inPage(FONT, SENT, INDEX) {
  const noteName = __NOTE_NAME__;
  const out = { notes: [], errors: [] };
  const finish = () => {
    const s = document.createElement('script');
    s.type = 'application/json';
    s.id = 'vr-out';
    s.textContent = JSON.stringify(out).replace(/</g, '\\u003c');
    document.body.append(s);
  };
  (async () => {
    const diagrams = [...document.querySelectorAll('.mermaid')];
    if (diagrams.length) {
      try {
        const { default: mermaid } = await import('https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs');
        const c = Object.fromEntries(Object.entries(SENT).map(([k, v]) => [k, v[0]]));
        mermaid.initialize({
          startOnLoad: false, theme: 'base', securityLevel: 'loose', htmlLabels: false,
          deterministicIds: true, deterministicIDSeed: 'vr',
          flowchart: { useMaxWidth: true, curve: 'basis', htmlLabels: false }, sequence: { useMaxWidth: true },
          themeVariables: {
            darkMode: true, fontFamily: FONT, background: c.background,
            primaryColor: c.node, mainBkg: c.node, primaryBorderColor: c.border, nodeBorder: c.border,
            primaryTextColor: c.text, textColor: c.text, nodeTextColor: c.text, titleColor: c.text,
            lineColor: c.line, clusterBkg: c.cluster, clusterBorder: c.clusterBorder, edgeLabelBackground: c.edgeLabel,
            actorBkg: c.node, actorBorder: c.border, actorTextColor: c.text, actorLineColor: c.clusterBorder,
            signalColor: c.line, signalTextColor: c.text, labelBoxBkgColor: c.node, labelBoxBorderColor: c.border,
            labelTextColor: c.text, loopTextColor: c.text, noteBkgColor: c.note, noteBorderColor: c.note,
            noteTextColor: c.text, activationBkgColor: c.node, activationBorderColor: c.border, sequenceNumberColor: c.text,
          },
        });
        await mermaid.run({ nodes: diagrams });
      } catch (e) {
        out.errors.push(`mermaid: ${e && e.message ? e.message : e}`);
      }
      const INH = ['fill', 'fill-opacity', 'stroke', 'stroke-width', 'stroke-dasharray', 'stroke-opacity', 'stroke-linecap', 'stroke-linejoin', 'font-family', 'font-size', 'font-weight', 'font-style', 'text-anchor', 'dominant-baseline', 'visibility', 'color'];
      const NON = { opacity: '1', display: 'inline' };
      for (const svg of document.querySelectorAll('.mermaid svg')) {
        const plan = [];
        const rootCs = getComputedStyle(svg);
        plan.push([svg, INH.map(p => `${p}:${rootCs.getPropertyValue(p)}`).join(';')]);
        for (const el of svg.querySelectorAll('*')) {
          if (el.tagName === 'style') continue;
          const cs = getComputedStyle(el), pcs = getComputedStyle(el.parentElement);
          const d = [];
          for (const p of INH) { const v = cs.getPropertyValue(p); if (v !== pcs.getPropertyValue(p)) d.push(`${p}:${v}`); }
          for (const [p, init] of Object.entries(NON)) { const v = cs.getPropertyValue(p); if (v !== init) d.push(`${p}:${v}`); }
          plan.push([el, d.join(';')]);
        }
        for (const [el, d] of plan) {
          if (el === svg) el.setAttribute('style', `${el.getAttribute('style') || ''};${d}`);
          else if (d) el.setAttribute('style', d);
          else el.removeAttribute('style');
        }
        svg.querySelectorAll('style').forEach(s => s.remove());
      }
      for (const el of document.querySelectorAll('.mermaid')) {
        if (!el.querySelector('svg')) out.errors.push(`diagram did not render: ${el.textContent.trim().slice(0, 80)}`);
        const d = document.createElement('div');
        d.className = 'mer';
        d.append(...el.childNodes);
        el.replaceWith(d);
      }
    }

    const root = document.querySelector('main') || document.body;
    const notes = [...root.querySelectorAll('[data-note]')].filter(el => !el.parentElement.closest('[data-note]'));
    const names = new Map(notes.map(el => [el, noteName(el.dataset.note)]));
    const seen = new Set();
    for (const n of names.values()) { if (seen.has(n)) out.errors.push(`duplicate note name: ${n}`); seen.add(n); }

    // in-page anchors become wikilink-style internal links to the note holding the target
    for (const a of root.querySelectorAll('a[href^="#"]')) {
      const id = decodeURIComponent(a.getAttribute('href').slice(1));
      const t = id ? document.getElementById(id) : null;
      const host = t && notes.find(n => n === t || n.contains(t));
      const target = host ? names.get(host) : t ? INDEX : null;
      if (!target) { a.removeAttribute('href'); continue; }
      a.setAttribute('href', target);
      a.setAttribute('data-href', target);
      a.classList.add('internal-link');
    }

    for (const el of notes) {
      let props = {};
      try { props = JSON.parse(el.dataset.props || '{}'); } catch { out.errors.push(`bad data-props on ${names.get(el)}`); }
      const c = el.cloneNode(true);
      c.removeAttribute('data-note');
      c.removeAttribute('data-props');
      out.notes.push({ name: names.get(el), props, html: c.outerHTML });
    }
    const idx = root.cloneNode(true);
    idx.querySelectorAll('[data-note], [data-note-skip]').forEach(el => el.remove());
    let indexProps = {};
    try { indexProps = JSON.parse(root.dataset.props || '{}'); } catch { out.errors.push('bad data-props on the index'); }
    const layout = /^(max-w-|mx-|my-|px-|py-|pt-|pb-|p-|m-|min-h-|h-screen)/;
    out.index = {
      props: indexProps,
      cls: (root === document.body ? '' : root.className).split(/\s+/).filter(c => c && !layout.test(c)).join(' '),
      html: idx.innerHTML,
    };
    out.title = document.title;
  })()
    .catch(e => out.errors.push(String(e && e.stack ? e.stack : e)))
    .finally(finish);
}

function renderReport(reportPath, indexName) {
  const src = readFileSync(reportPath, 'utf8');
  // the report's own Tailwind and Mermaid loaders go; ours replaces them
  let html = src
    .replace(/<script\b[^>]*\bsrc=["'][^"']*(tailwindcss|mermaid)[^"']*["'][^>]*>\s*<\/script>/gi, '')
    .replace(/<script\b[^>]*>(?:(?!<\/script>)[\s\S])*?(mermaid|tailwind\.config)[\s\S]*?<\/script>/gi, '');
  const font = textFont();
  const call = `(${inPage.toString().replace('__NOTE_NAME__', noteName.toString())})(${JSON.stringify(font)}, ${JSON.stringify(SENTINELS)}, ${JSON.stringify(indexName)});`;
  const base = `<base href="${pathToFileURL(dirname(resolve(reportPath))).href}/">`;
  html = /<head[^>]*>/i.test(html) ? html.replace(/<head[^>]*>/i, m => `${m}${base}`) : base + html;
  html = /<\/body>/i.test(html) ? html.replace(/<\/body>(?![\s\S]*<\/body>)/i, `<script type="module">${call}</script></body>`) : `${html}<script type="module">${call}</script>`;
  const dir = mkdtempSync(join(tmpdir(), 'vault-report-'));
  const page = join(dir, 'page.html');
  writeFileSync(page, html);
  const r = spawnSync(chrome(), ['--headless=new', '--disable-gpu', '--window-size=1400,1200', '--virtual-time-budget=30000', '--dump-dom', pathToFileURL(page).href], {
    encoding: 'utf8', maxBuffer: 256 * 1024 * 1024, timeout: 180000,
  });
  const m = (r.stdout || '').match(/<script type="application\/json" id="vr-out">([\s\S]*?)<\/script>/);
  if (!m) die(`render did not finish (chrome exit ${r.status}). Page kept at ${page}`);
  const out = JSON.parse(m[1]);
  if (out.errors.length) die(`render errors:\n  ${out.errors.join('\n  ')}`);
  return { out, styles: [...src.replace(/<svg[\s\S]*?<\/svg>/gi, '').matchAll(/<style[^>]*>([\s\S]*?)<\/style>/gi)].map(x => x[1]).join('\n') };
}

function textFont() {
  try {
    const a = JSON.parse(readFileSync(join(VAULT, '.obsidian/appearance.json'), 'utf8'));
    if (a.textFontFamily) return `"${a.textFontFamily}", -apple-system, "Helvetica Neue", Arial, sans-serif`;
  } catch {}
  return '-apple-system, "Helvetica Neue", Arial, sans-serif';
}

// ---------- step 2: theme literal colours, make the HTML safe for Obsidian's Markdown ----------
const decode = s => s.replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&');
const encode = s => s.replace(/&/g, '&amp;').replace(/"/g, '&quot;');
const SVG_COLOR_ATTRS = ['fill', 'stroke', 'stop-color', 'flood-color', 'color'];

function themeHtml(html) {
  let svgDepth = 0;
  return html.replace(/<(\/?)([a-zA-Z][\w:-]*)((?:\s+[^\s=>/]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+))?)*)\s*(\/?)>/g, (m, close, tag, attrs, self) => {
    const t = tag.toLowerCase();
    if (close) {
      if (t === 'svg') svgDepth--;
      return m;
    }
    if (t === 'svg' && !self) svgDepth++;
    const inSvg = svgDepth > 0 || t === 'svg';
    let style = '';
    const lifted = [];
    const kept = attrs.replace(/\s+([^\s=>/]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g, (am, name, dq, sq, bare) => {
      const n = name.toLowerCase(), v = dq ?? sq ?? bare ?? '';
      if (n === 'style') { style = decode(v); return ''; }
      if (inSvg && SVG_COLOR_ATTRS.includes(n) && /#|rgb|\bwhite\b|\bblack\b/i.test(v)) { lifted.push(`${n}:${v}`); return ''; }
      return am;
    });
    if (!style && !lifted.length) return m;
    const decls = [...lifted, ...style.split(';')].filter(d => d.includes(':')).map(d => {
      const i = d.indexOf(':');
      const prop = d.slice(0, i).trim(), val = d.slice(i + 1).trim();
      return `${prop}:${themeValue(val, kindForProp(prop, t), { svg: inSvg })}`;
    });
    return `<${tag}${kept} style="${encode(decls.join(';'))}"${self ? ' /' : ''}>`;
  });
}

// Obsidian ends an HTML block at a blank line and reads indented lines after one as code, so
// every block goes out with no blank lines and no indentation. <pre> keeps its newlines as entities.
function obsidianSafe(html) {
  return html
    .replace(/(<pre\b[^>]*>)([\s\S]*?)(<\/pre>)/gi, (m, a, body, b) => a + body.replace(/\n/g, '&#10;').replace(/^ /gm, '&#32;') + b)
    .replace(/\n\s*/g, '\n')
    .trim();
}

const pageWrap = (cls, body) => `<div class="vr-page ${cls}">\n${body}\n</div>`;

// ---------- step 3: per-report CSS (the report's own <style>), scoped and themed ----------
function reportCss(postcss, css, scopeCls) {
  if (!css.trim()) return '';
  const root = postcss.parse(css);
  const scope = `.${CLASS} .vr-page.${scopeCls}`;
  root.walkRules(rule => {
    if (rule.parent?.type === 'atrule' && /keyframes/.test(rule.parent.name)) return;
    rule.selectors = rule.selectors.map(s => {
      const t = s.trim();
      if (/^(html|body|:root)$/.test(t)) return scope;
      return `${scope} ${t.replace(/^(html|body|:root)\s+/, '').replace(/pre\.mermaid|\.mermaid/g, '.mer')}`;
    });
    rule.walkDecls(d => {
      const pageLevel = rule.selectors.includes(scope);
      if (pageLevel && /^background/.test(d.prop)) return d.remove();
      d.value = themeValue(d.value, kindForProp(d.prop, ''), {});
      if (!d.prop.startsWith('--')) d.important = true;
    });
  });
  root.walkComments(c => c.remove());
  return `/* ${scopeCls} */\n${root.toString()}\n`;
}

// ---------- step 4: one shared snippet, built from every vault-report note in the vault ----------
function walk(dir, found = { notes: [], css: [] }) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) {
      if (e.name.startsWith('.') || e.name === 'node_modules') continue;
      walk(p, found);
    } else if (e.name === '.vault-report.css') found.css.push(p);
    else if (e.name.endsWith('.md')) {
      const head = readFileSync(p, 'utf8').slice(0, 4000);
      const fm = head.match(/^---\n([\s\S]*?)\n---/);
      if (fm && /(^|\n)cssclasses?:[^\n]*(\n[ \t]+-[^\n]*)*/.exec(fm[1])?.[0].match(new RegExp(`\\b${CLASS}\\b`))) found.notes.push(p);
    }
  }
  return found;
}

// type: body and headings in the theme's text face, instrumentation in its code face
const FONTS = { sans: ['var(--font-text)'], serif: ['var(--font-text)'], mono: ['"Recursive"', 'var(--font-monospace)'] };

async function rebuildSnippet({ postcss, tailwind, colors }) {
  setPalette(colors);
  const { notes, css } = walk(VAULT);
  const content = notes.map(p => readFileSync(p, 'utf8')).join('\n');
  const SCOPE = `.${CLASS} .vr-page`;
  const build = async (input, important) => {
    const config = { content: [{ raw: content, extension: 'html' }], important, theme: { ...tailwindTheme(), fontFamily: FONTS }, corePlugins: {} };
    const r = await postcss([tailwind(config)]).process(input, { from: undefined });
    return r.root;
  };
  const scope = (root, important) => {
    root.walkRules(rule => {
      if (rule.parent?.type === 'atrule' && /keyframes/.test(rule.parent.name)) return;
      const sels = [];
      for (const s of rule.selectors) {
        const t = s.trim();
        if (t === 'body') continue;
        if (t === 'html' || t === ':host') sels.push(SCOPE);
        else if (t === '*') sels.push(SCOPE, `${SCOPE} *`);
        else sels.push(`${SCOPE} ${t}`);
      }
      if (!sels.length) return rule.remove();
      rule.selectors = [...new Set(sels)];
      rule.walkDecls(d => {
        if (/#|rgb|\bwhite\b|\bblack\b/.test(d.value)) d.value = themeValue(d.value, kindForProp(d.prop, ''), {});
        if (important && !d.prop.startsWith('--')) d.important = true;
      });
    });
    // an Obsidian pane is narrower than the window: viewport breakpoints become container queries
    root.walkAtRules('media', at => {
      const m = at.params.match(/^\(min-width:\s*(\d+)px\)$/);
      if (!m) return;
      const px = { 640: 600, 768: 720, 1024: 880, 1280: 1100, 1536: 1300 }[m[1]] ?? +m[1];
      at.name = 'container';
      at.params = `vr (min-width: ${px}px)`;
    });
    // Obsidian sets the root font size to its own text size; reports assume 16px
    root.walkDecls(d => { d.value = d.value.replace(/(-?\d*\.?\d+)rem\b/g, (m, n) => `${+(n * 16).toFixed(3)}px`); });
    root.walkComments(c => c.remove());
    return root.toString();
  };
  // preflight is marked !important so theme and snippet rules on h1, code, table, li can't win;
  // utilities already are (important: true)
  const base = scope(await build('@tailwind base;', true), true);
  const utils = scope(await build('@tailwind components;\n@tailwind utilities;', true), false);
  const extra = css.map(p => readFileSync(p, 'utf8')).join('\n');
  const S = SCOPE;
  const custom = `
/* page: sits on the note background at the report's width */
${S} { container: vr / inline-size; max-width: 1152px; margin: 0 auto 32px; color: ${C.fg}; font-family: var(--font-text); font-size: var(--font-text-size, 16px); }
.${CLASS} .inline-title { display: none; }
/* Obsidian and common snippets style these with higher specificity */
${S} td, ${S} th, ${S} tr { padding: 0 !important; background: transparent !important; width: auto !important; font-weight: inherit !important; color: inherit !important; line-height: inherit !important; vertical-align: inherit !important; border-right: 0 !important; font-size: inherit !important; font-family: inherit !important; white-space: normal !important; }
${S} strong, ${S} b { color: inherit !important; font-weight: 600 !important; }
${S} em, ${S} i { color: inherit !important; }
${S} table { border-radius: 0 !important; overflow: visible !important; font-size: inherit !important; border-collapse: collapse; }
${S} h1, ${S} h2, ${S} h3, ${S} h4, ${S} h5, ${S} h6 { color: inherit !important; line-height: inherit !important; border: 0 !important; padding: 0 !important; }
${S} code { color: inherit !important; background: transparent !important; padding: 0 !important; border-radius: 0 !important; font-size: 1em !important; }
${S} a, ${S} a.internal-link { color: inherit !important; text-decoration: none !important; border-bottom: 0 !important; }
${S} li { margin: 0 !important; }
${S} ul.list-disc > li, ${S} ol.list-decimal > li { display: list-item; }
${S} li::marker { color: var(--list-marker-color, ${C.teal}); }
/* serif display type becomes the text face at semibold; code keeps the theme's Recursive axes */
${S} .font-serif { font-weight: 600 !important; letter-spacing: -0.015em !important; }
${S} .font-mono, ${S} code, ${S} pre, ${S} kbd, ${S} samp { font-variation-settings: "MONO" 1, "CASL" 0.5, "slnt" 0, "CRSV" 0.5; }
/* inline code with a background reads as the theme's inline code */
${S} code[class*="bg-"] { color: ${C.orange} !important; background: color-mix(in srgb, ${C.orange} 12%, transparent) !important; }
/* the theme's raised-panel idiom: a hairline highlight, no drop shadow */
${S} [class*="shadow"] { box-shadow: inset 0 1px 0 color-mix(in srgb, ${C.fg} 6%, transparent) !important; }
${S} .mer { display: flex; justify-content: center; }
${S} .mer svg { height: auto; }
`;
  const out = join(VAULT, '.obsidian/snippets', `${SNIPPET}.css`);
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, `/* vault-report: Tailwind + Mermaid reports as notes (cssclasses: ${CLASS}). Generated by ~/.agents/skills/vault-report; do not edit by hand. */\n${base}\n${utils}\n${custom}\n${extra}`);
  enableSnippet();
  return { out, notes: notes.length, reports: css.length };
}

function enableSnippet() {
  const cli = '/Applications/Obsidian.app/Contents/MacOS/obsidian-cli';
  const appearance = join(VAULT, '.obsidian/appearance.json');
  // With the vault open, ask Obsidian: it rereads the snippets folder and saves appearance.json
  // itself (an edit from outside would be overwritten). The CLI exits 0 even on errors.
  if (existsSync(cli)) {
    const n = JSON.stringify(SNIPPET);
    const code = `(async () => { await app.customCss.readSnippets(); app.customCss.setCssEnabledStatus(${n}, true); return app.customCss.enabledSnippets.has(${n}) ? "vr-enabled" : "vr-missing" })()`;
    const r = spawnSync(cli, ['eval', `vault=${basename(VAULT)}`, `code=${code}`], { encoding: 'utf8', timeout: 15000 });
    if (/vr-enabled/.test(r.stdout || '')) return;
  }
  const a = JSON.parse(readFileSync(appearance, 'utf8'));
  if ((a.enabledCssSnippets || []).includes(SNIPPET)) return;
  a.enabledCssSnippets = [...(a.enabledCssSnippets || []), SNIPPET];
  writeFileSync(appearance, `${JSON.stringify(a, null, 2)}\n`);
  console.log('enabled the snippet in appearance.json (Obsidian was not reachable)');
}

// ---------- main ----------
const D = deps();
if (opts.rebuild) {
  const r = await rebuildSnippet(D);
  console.log(`rebuilt ${r.out} from ${r.notes} notes, ${r.reports} report stylesheets`);
  process.exit(0);
}

const [report] = opts.positional;
if (!report || !opts.dest) die('usage: vault-report.mjs <report.html> --dest "<vault folder>" [--name "<index note>"]');
const destDir = resolve(VAULT, opts.dest);
if (relative(VAULT, destDir).startsWith('..')) die('--dest must be inside the vault');
const date = opts.date || new Date().toISOString().slice(0, 10);
const indexName = noteName(opts.name || basename(destDir));
const { out, styles } = renderReport(report, indexName);
if (!out.notes.length) console.log('no [data-note] sections; the whole report becomes one note');
setPalette(D.colors);

const cls = `vr-${slug(indexName)}`;
const files = [];
for (const n of out.notes) {
  const body = obsidianSafe(pageWrap(cls, themeHtml(n.html)));
  const fm = frontmatter({ status: opts.status || 'needs-review', date, ...n.props, report: `[[${indexName}]]` });
  files.push([`${n.name}.md`, `${fm}${body}\n`]);
}
const indexBody = obsidianSafe(pageWrap(cls, `<div class="${out.index.cls}">\n${themeHtml(out.index.html)}\n</div>`));
const indexFm = frontmatter({ status: opts.status || 'needs-review', date, ...out.index.props, notes: out.notes.length ? out.notes.map(n => `[[${n.name}]]`) : null });
files.push([`${indexName}.md`, `${indexFm}${indexBody}\n`]);

for (const [f, text] of files) {
  const blank = text.split(/\n---\n/).slice(1).join('\n---\n');
  if (/\n[ \t]*\n/.test(blank)) die(`blank line inside the HTML of ${f}`);
}
const clashes = files.map(([f]) => join(destDir, f)).filter(existsSync);
if (clashes.length && !opts.force) die(`these notes exist; check them for your own edits, then pass --force:\n  ${clashes.map(p => relative(VAULT, p)).join('\n  ')}`);
mkdirSync(destDir, { recursive: true });
for (const [f, text] of files) writeFileSync(join(destDir, f), text);
writeFileSync(join(destDir, '.vault-report.css'), reportCss(D.postcss, styles, cls));

const written = new Set(files.map(([f]) => f));
const stale = readdirSync(destDir).filter(f => f.endsWith('.md') && !written.has(f) && /\n  - vault-report\n/.test(readFileSync(join(destDir, f), 'utf8').slice(0, 2000)));
const r = await rebuildSnippet(D);
console.log(`wrote ${files.length} notes to ${relative(VAULT, destDir)}/ (index: ${indexName})`);
console.log(`snippet ${relative(VAULT, r.out)} covers ${r.notes} notes across ${r.reports} reports`);
if (stale.length) console.log(`not from this export, left alone:\n  ${stale.join('\n  ')}`);
