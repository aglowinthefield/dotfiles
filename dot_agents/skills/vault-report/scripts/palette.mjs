// Maps the report's colours onto the Obsidian theme, by role.
//
// Reports are designed light (white cards on a stone page, slate text, red/emerald/amber
// accents). Each Tailwind family and shade gets a role in the theme instead of a fixed
// colour: white cards become raised panels, slate-900 slabs become dark slabs, red-50
// washes become a 10% wash of the theme's red. Compline's --c-* variables come first,
// with Obsidian's own variables as the fallback so another theme still reads.

export const C = {
  bg: 'var(--c-bg, var(--background-primary))',
  bg2: 'var(--c-bg2, var(--background-secondary))',
  fg: 'var(--c-fg, var(--text-normal))',
  fg2: 'var(--c-fg2, var(--text-muted))',
  dim: 'var(--c-dim, var(--text-faint))',
  sel: 'var(--c-sel, var(--background-modifier-hover))',
  red: 'var(--c-red, var(--color-red))',
  orange: 'var(--c-orange, var(--color-orange))',
  yellow: 'var(--c-yellow, var(--color-yellow))',
  green: 'var(--c-green, var(--color-green))',
  teal: 'var(--c-teal, var(--color-cyan))',
  cyan: 'var(--c-cyan, var(--color-cyan))',
  link: 'var(--c-link, var(--text-accent))',
  magenta: 'var(--c-magenta, var(--color-purple))',
};

export const NEUTRALS = ['slate', 'gray', 'zinc', 'neutral', 'stone'];
export const HUES = {
  red: 'red', rose: 'red', orange: 'orange', amber: 'yellow', yellow: 'yellow',
  lime: 'green', green: 'green', emerald: 'green', teal: 'teal', cyan: 'cyan', sky: 'cyan',
  blue: 'link', indigo: 'link', violet: 'magenta', purple: 'magenta', fuchsia: 'magenta', pink: 'magenta',
};
export const SHADES = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950];

const SLAB = `color-mix(in srgb, ${C.fg} 8%, ${C.bg})`;
const SLAB2 = `color-mix(in srgb, ${C.fg} 14%, ${C.bg})`;

// A role is [colour, percent, base]. base 'over' means a wash: transparent in HTML (it
// sits on whatever panel is behind it) and over the raised panel in SVG, where shapes
// must stay opaque so edges don't show through.
const wash = (c, p) => [c, p, 'over'];
const solid = c => [c, 100, 'over'];

const ROLES = {
  bg: {
    white: solid(C.bg2), black: solid(SLAB),
    neutral: { 50: solid(C.bg), 100: wash(C.fg, 8), 200: wash(C.fg, 12), 300: wash(C.fg, 18), 400: wash(C.fg, 28), 500: wash(C.fg, 40), 600: solid(SLAB2), 700: solid(SLAB2), 800: solid(SLAB), 900: solid(SLAB), 950: solid(SLAB) },
    hue: c => ({ 50: wash(c, 10), 100: wash(c, 18), 200: wash(c, 26), 300: wash(c, 36), 400: wash(c, 48), 500: solid(`color-mix(in srgb, ${c} 34%, ${C.bg2})`), 600: solid(`color-mix(in srgb, ${c} 28%, ${C.bg2})`), 700: solid(`color-mix(in srgb, ${c} 22%, ${C.bg})`), 800: solid(`color-mix(in srgb, ${c} 16%, ${C.bg})`), 900: solid(`color-mix(in srgb, ${c} 12%, ${C.bg})`), 950: solid(`color-mix(in srgb, ${c} 9%, ${C.bg})`) }),
  },
  text: {
    white: solid(C.fg), black: solid(C.fg),
    neutral: { 50: solid(C.fg), 100: solid(C.fg), 200: solid(C.fg), 300: wash(C.fg2, 55), 400: wash(C.fg2, 55), 500: solid(C.fg2), 600: solid(C.fg2), 700: solid(C.fg), 800: solid(C.fg), 900: solid(C.fg), 950: solid(C.fg) },
    hue: c => Object.fromEntries(SHADES.map(s => [s, solid(c)])),
  },
  border: {
    white: wash(C.fg, 10), black: wash(C.fg, 22),
    neutral: { 50: wash(C.fg, 6), 100: wash(C.fg, 8), 200: wash(C.fg, 10), 300: wash(C.fg, 16), 400: wash(C.fg, 24), 500: wash(C.fg, 32), 600: wash(C.fg, 40), 700: wash(C.fg, 45), 800: wash(C.fg, 22), 900: wash(C.fg, 22), 950: wash(C.fg, 22) },
    hue: c => ({ 50: wash(c, 15), 100: wash(c, 20), 200: wash(c, 30), 300: wash(c, 40), 400: wash(c, 55), 500: wash(c, 70), 600: wash(c, 80), 700: wash(c, 85), 800: wash(c, 85), 900: wash(c, 85), 950: wash(c, 85) }),
  },
};

export const role = (kind, family, shade) => {
  const r = ROLES[kind];
  if (family === 'white' || family === 'black') return r[family];
  if (NEUTRALS.includes(family)) return r.neutral[shade];
  if (HUES[family]) return r.hue(C[HUES[family]])[shade];
  return null;
};

// With a low opacity modifier, a dark shade means a tint of ink rather than a dark surface:
// bg-slate-900/5 on a light card is a faint shadow tone, so on any theme it becomes a faint
// wash of the text colour, and bg-emerald-500/10 a wash of the theme's green. Above
// INK_MAX (bg-slate-800/50 inside a dark slab) it is still a see-through surface.
export const INK_MAX = 0.25;
export const ink = (kind, family, shade) => {
  if (kind === 'text') return null;
  if (family === 'black' || (NEUTRALS.includes(family) && shade >= 500)) return C.fg;
  if (HUES[family] && shade >= 500) return C[HUES[family]];
  return null;
};
const inkAt = (c, a) => `color-mix(in srgb, ${c} ${+(a * 100).toFixed(2)}%, transparent)`;

// CSS for a role. alpha is a CSS number expression (Tailwind's <alpha-value>, or a
// literal from rgba()); svg makes washes opaque over the raised panel.
export const expr = ([c, p, base], { alpha = null, svg = false } = {}) => {
  const pct = alpha == null ? `${p}%` : `calc(${alpha} * ${p}%)`;
  if (p === 100 && alpha == null) return c;
  const under = svg && base === 'over' && alpha == null ? C.bg2 : 'transparent';
  return `color-mix(in srgb, ${c} ${pct}, ${under})`;
};

// Tailwind theme: every colour key the report could use resolves to a role, per property.
// Colours are functions so a literal opacity modifier (/5) can switch to ink; without one,
// Tailwind passes var(--tw-bg-opacity) and the role holds.
const colorFn = (r, inkColor) => ({ opacityValue: a } = {}) => {
  if (a == null) return expr(r);
  if (inkColor && /^(0?\.\d+|0)$/.test(a) && +a <= INK_MAX) return inkAt(inkColor, +a);
  return expr(r, { alpha: a });
};

export function tailwindTheme() {
  const families = ['white', 'black', ...NEUTRALS, ...Object.keys(HUES)];
  const map = kind => {
    const out = { inherit: 'inherit', current: 'currentColor', transparent: 'transparent' };
    for (const f of families) {
      if (f === 'white' || f === 'black') { out[f] = colorFn(role(kind, f), ink(kind, f)); continue; }
      out[f] = Object.fromEntries(SHADES.map(s => [s, colorFn(role(kind, f, s), ink(kind, f, s))]));
    }
    // preflight's default border and ring colour (gray-200 in stock Tailwind)
    if (kind === 'border') out.DEFAULT = colorFn(role('border', 'gray', 200), null);
    return out;
  };
  const bg = map('bg'), text = map('text'), border = map('border');
  return {
    colors: text,
    backgroundColor: bg, gradientColorStops: bg, ringOffsetColor: bg, fill: bg,
    textColor: text, placeholderColor: text, textDecorationColor: text, caretColor: text, accentColor: text,
    borderColor: border, divideColor: border, outlineColor: border, ringColor: border, stroke: border,
  };
}

// Literal colours (inline styles, SVG attributes, the report's own <style>): find the
// nearest Tailwind colour, then use its role for the property being set.
let PALETTE = null;
export function setPalette(colors) {
  PALETTE = [['white', null, '#ffffff'], ['black', null, '#000000']];
  for (const f of [...NEUTRALS, ...Object.keys(HUES)]) for (const s of SHADES) PALETTE.push([f, s, colors[f][s]]);
  PALETTE = PALETTE.map(([f, s, hex]) => [f, s, hexRgb(hex)]);
}
const hexRgb = h => {
  h = h.replace('#', '');
  if (h.length === 3 || h.length === 4) h = [...h].map(x => x + x).join('');
  return [0, 2, 4].map(i => parseInt(h.slice(i, i + 2), 16));
};
const nearest = rgb => {
  let best = null, bd = Infinity;
  for (const [f, s, p] of PALETTE) {
    const d = (p[0] - rgb[0]) ** 2 + (p[1] - rgb[1]) ** 2 + (p[2] - rgb[2]) ** 2;
    if (d < bd) { bd = d; best = [f, s]; }
  }
  return best;
};

export const kindForProp = (prop, tag = '') => {
  prop = prop.toLowerCase();
  if (prop === '--tw-ring-offset-color') return 'bg';
  if (/^--tw-(ring|shadow)-color$/.test(prop)) return 'border';
  if (prop === 'color') return 'text';
  if (prop === 'fill') return /^(text|tspan|textpath)$/i.test(tag) ? 'text' : 'bg';
  if (prop.startsWith('background') || prop === 'stop-color' || prop === 'flood-color') return 'bg';
  if (prop.startsWith('border') || prop.startsWith('outline') || prop === 'stroke' || prop.startsWith('box-shadow') || prop === 'column-rule-color' || prop === 'text-decoration-color') return 'border';
  return null;
};

// Mermaid renders with these sentinel colours (Compline's dark values, none of them a
// Tailwind colour), and each one maps back to a theme role. Mermaid derives a few colours
// of its own; those fall through to the nearest Tailwind colour.
export const SENTINELS = {
  node: ['#25282c', C.bg2],
  border: ['#525354', `color-mix(in srgb, ${C.fg} 24%, ${C.bg2})`],
  text: ['#e0dcd4', C.fg],
  line: ['#7e7d7c', `color-mix(in srgb, ${C.fg2} 60%, ${C.bg})`],
  cluster: ['#202327', `color-mix(in srgb, ${C.fg} 4%, transparent)`],
  clusterBorder: ['#3a3c3f', `color-mix(in srgb, ${C.fg} 14%, transparent)`],
  edgeLabel: ['#1e2125', `color-mix(in srgb, ${C.bg} 60%, ${C.bg2})`],
  note: ['#3d424a', C.sel],
  background: ['#1a1d21', C.bg],
};
const MERMAID_RGB = Object.fromEntries(Object.values(SENTINELS).map(([h, v]) => [hexRgb(h).join(','), v]));

// Replace every literal colour in a CSS value. kind decides the role; svg makes washes opaque.
export function themeValue(value, kind, { svg = false } = {}) {
  if (!kind) return value;
  // alpha: null, a number, or a CSS expression such as var(--tw-bg-opacity)
  const sub = (rgb, a) => {
    const m = MERMAID_RGB[rgb.join(',')];
    const pct = typeof a === 'number' ? `${Math.round(a * 100)}%` : `calc(${a} * 100%)`;
    if (m) return a == null || a === 1 ? m : `color-mix(in srgb, ${m} ${pct}, transparent)`;
    const [f, s] = nearest(rgb);
    const r = role(kind, f, s);
    if (a == null || a === 1) return expr(r, { svg });
    const k = ink(kind, f, s);
    if (k && typeof a === 'number' && a <= INK_MAX) return inkAt(k, a);
    return expr(r, { alpha: String(a) });
  };
  return value
    .replace(/rgba?\(\s*(\d+)[,\s]+(\d+)[,\s]+(\d+)(?:\s*[,/]\s*(var\([^)]*\)|[\d.]+%?))?\s*\)/g, (m, r, g, b, a) => {
      const alpha = a == null ? null : a.startsWith('var(') ? a : a.endsWith('%') ? parseFloat(a) / 100 : parseFloat(a);
      if (alpha === 0) return 'transparent';
      return sub([+r, +g, +b], alpha);
    })
    .replace(/#([0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3,4})\b/g, (m, h) => {
      const a = h.length === 8 ? parseInt(h.slice(6), 16) / 255 : h.length === 4 ? parseInt(h[3] + h[3], 16) / 255 : null;
      if (a === 0) return 'transparent';
      return sub(hexRgb(h.slice(0, h.length === 8 ? 6 : h.length === 4 ? 3 : h.length)), a);
    })
    .replace(/\b(white|black)\b/g, w => (kind ? sub(w === 'white' ? [255, 255, 255] : [0, 0, 0], null) : w));
}
